/*
   Copyright (c) 2026, MariaDB

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; version 2 of the License.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1335
   USA */

/**
  @file

    Contains
*/


#include "sql_parallel_workers.h"

void add_random_warning_to_queue(pwt_queued_event **event, THD *thd)
{
  *event= (pwt_queued_event*) my_malloc(PSI_INSTRUMENT_ME,
                                           sizeof(pwt_queued_event),
                                           MYF(0));
  (*event)->next= nullptr;
  (*event)->type= pwt_queued_event::queued_event_t::QUEUED_WARNING;
  (*event)->warning= (pwt_warning_message*) my_malloc(PSI_INSTRUMENT_ME,
                                               sizeof(pwt_warning_message),
                                               MYF(0));
  (*event)->warning->code= 100+100.0*rand()/RAND_MAX;
  (*event)->warning->level= Sql_condition::enum_warning_level::WARN_LEVEL_WARN;
  sprintf((*event)->warning->message, "%s, error %u",
          thd->connection_name.str,
          (*event)->warning->code);
}


static void *parallel_worker_thread_func(void *arg)
{
  struct pwt_worker *worker= (struct pwt_worker*) arg;

  /*
    Set current_thd and thread local storage (my_thread_var) for our new THD
    to ensure they have their own local objects/error etc
  */
  void *save= thd_attach_thd(worker->thd);
  my_thread_set_name(worker->thd->connection_name.str);
  THD_STAGE_INFO(worker->thd, stage_sending_data);
  my_sleep(1000000+1000000*(double)rand()/RAND_MAX); /* 1-11 seconds */

  // add an event to our queue
  mysql_mutex_lock(&worker->manager->LOCK_pwt_thread);
  if (worker->messages->event_queue)
  {
    pwt_queued_event *last= worker->messages->event_queue;

    while( last->next )
      last= last->next;

    add_random_warning_to_queue(&last->next, worker->thd);
    worker->messages->last_in_queue= last->next;
  }
  else
  {
    add_random_warning_to_queue(&worker->messages->event_queue, worker->thd);
    worker->messages->last_in_queue= worker->messages->event_queue;
  }
  mysql_mutex_unlock(&worker->manager->LOCK_pwt_thread);

  // signal manager there is something in the queue
  mysql_cond_signal(&worker->manager->COND_pwt_new_message);

  my_sleep(20000000+1000000*(double)rand()/RAND_MAX); /* 20-31 seconds */
  worker->finished= true;

  // signal manager again to wake up and end this thread
  mysql_cond_signal(&worker->manager->COND_pwt_new_message);

  // restore saved state
  thd_detach_thd(save);
  server_threads.erase(worker->thd);
  destroy_background_thd(worker->thd);
  return nullptr;
}

#define WORKER_NAME "parallel worker"

#ifdef HAVE_PSI_INTERFACE
static PSI_thread_key key_thread_pwt;

static PSI_thread_info all_pwt_threads[]=
{
  { &key_thread_pwt, WORKER_NAME, PSI_FLAG_GLOBAL},
};
#endif /* HAVE_PSI_INTERFACE */


bool pwt_management::init_parallel_workers(THD *thd)
{
  if (const uint n= thd->variables.parallel_worker_threads)
  {
    workers= (struct pwt_worker *) my_malloc(PSI_INSTRUMENT_ME,
                                     n * sizeof(struct pwt_worker),
                                     MYF(0));
    if (!workers)
      return false;
    nworkers= n;

    mysql_mutex_init(PSI_INSTRUMENT_ME, &LOCK_pwt_manager, MY_MUTEX_INIT_SLOW);
    mysql_mutex_init(PSI_INSTRUMENT_ME, &LOCK_pwt_thread, MY_MUTEX_INIT_SLOW);
    mysql_cond_init(key_COND_parallel_entry, &COND_pwt_new_message, NULL);
    for (uint i= 0; i < n; i++)
    {
      workers[i].thd= create_background_thd();
      workers[i].manager= this;
      workers[i].messages= &parallel_messages;
      workers[i].thd->system_thread= SYSTEM_THREAD_GENERIC;
      size_t len= my_snprintf(workers[i].conn_name, MAX_THREAD_NAME,
                              WORKER_NAME);
      workers[i].thd->connection_name.str= workers[i].conn_name;
      workers[i].thd->connection_name.length= len;
      workers[i].thd->security_ctx= thd->security_ctx;
      workers[i].thd->set_command(thd->get_command());
      // explicit call to my_free in THD::free_connection(), so we do this
      workers[i].thd->db.str= (char*)my_malloc(PSI_INSTRUMENT_ME,
                                               thd->db.length+1,
                                               MYF(0));
      strncpy(const_cast<char*>(workers[i].thd->db.str), thd->db.str,
              thd->db.length);
      workers[i].thd->db.length= thd->db.length;
      workers[i].thd->proc_info= thd->proc_info;
      workers[i].thd->start_utime= thd->start_utime;
      workers[i].thd->thread_id= thd->thread_id;
      workers[i].thd->query_string= thd->query_string;
//      workers[i].thd->progress=   hmmm;

      workers[i].finished= workers[i].joined= false;

#ifdef HAVE_PSI_INTERFACE
      if (PSI_server)
        PSI_server->register_thread("sql", all_pwt_threads,
                                    array_elements(all_pwt_threads));
#endif
      server_threads.insert(workers[i].thd);               // show processlist

      if (mysql_thread_create(key_thread_pwt, &workers[i].pthread, nullptr,
                              parallel_worker_thread_func, &workers[i]))
      {
        server_threads.erase(workers[i].thd);
        destroy_background_thd(workers[i].thd);
        for (uint j= 0; j < i; j++)
        {
          destroy_background_thd(workers[j].thd);
          pthread_join(workers[j].pthread, nullptr);
        }
        workers= nullptr;
        return false;
      }
    }
  }
  return true;
}


void pwt_management::join_parallel_workers(THD *thd)
{
  bool all_done= false;
  mysql_mutex_lock(&LOCK_pwt_manager);

  while (!all_done)
  {
    all_done= true;

    // delete worker threads that are finished
    for (uint i= 0; i < nworkers; i++)
    {
      if (workers[i].finished)
      {
        if (!workers[i].joined)
        {
          pthread_join(workers[i].pthread, nullptr);
          workers[i].joined= true;
        }
      }
      else
        all_done= false;
    }

    if (!all_done)
      mysql_cond_wait(&COND_pwt_new_message, &LOCK_pwt_manager);

    mysql_mutex_lock(&LOCK_pwt_thread);
    while(parallel_messages.event_queue)
    {
      switch(parallel_messages.event_queue->type)
      {
        case pwt_queued_event::QUEUED_ERROR:
          my_free(parallel_messages.event_queue->error);
          break;
        case pwt_queued_event::QUEUED_WARNING:
          push_warning(thd, parallel_messages.event_queue->warning->level,
                       parallel_messages.event_queue->warning->code,
                       parallel_messages.event_queue->warning->message);
          my_free(parallel_messages.event_queue->warning);
          break;
        case pwt_queued_event::QUEDED_DATA:
          break;
      }
      pwt_queued_event *last= parallel_messages.event_queue;
      parallel_messages.event_queue= parallel_messages.event_queue->next;
      my_free(last);
    }
    mysql_mutex_unlock(&LOCK_pwt_thread);
  }

  mysql_cond_destroy(&COND_pwt_new_message);
  mysql_mutex_unlock(&LOCK_pwt_manager);
  mysql_mutex_destroy(&LOCK_pwt_manager);
  mysql_mutex_destroy(&LOCK_pwt_thread);
  if (nworkers)
    my_free(workers);
}

