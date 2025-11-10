#include "threading.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

#define DEBUG_LOG(msg,...)
//#define DEBUG_LOG(msg,...) printf("threading: " msg "\n" , ##__VA_ARGS__)
#define ERROR_LOG(msg,...) printf("threading ERROR: " msg "\n" , ##__VA_ARGS__)

void* threadfunc(void* thread_param)
{
    struct thread_data* thread_func_args = (struct thread_data *) thread_param;
    if (thread_func_args == NULL) {
        ERROR_LOG("thread_func_args is NULL");
        pthread_exit(NULL);
    }

    // Initial assumption: fail until proven otherwise
    thread_func_args->thread_complete_success = false;

    // Wait before attempting to obtain mutex
    usleep(thread_func_args->wait_to_obtain_ms * 1000);

    // Attempt to obtain the mutex
    int rc = pthread_mutex_lock(thread_func_args->mutex);
    if (rc != 0) {
        ERROR_LOG("Failed to obtain mutex, code %d", rc);
        pthread_exit(thread_func_args);
    }

    // Wait before releasing the mutex
    usleep(thread_func_args->wait_to_release_ms * 1000);

    // Release the mutex
    rc = pthread_mutex_unlock(thread_func_args->mutex);
    if (rc != 0) {
        ERROR_LOG("Failed to release mutex, code %d", rc);
        pthread_exit(thread_func_args);
    }

    // Success
    thread_func_args->thread_complete_success = true;

    // Return pointer for joiner thread
    pthread_exit(thread_func_args);
}


bool start_thread_obtaining_mutex(pthread_t *thread, pthread_mutex_t *mutex, int wait_to_obtain_ms, int wait_to_release_ms)
{
    struct thread_data *thread_data = (struct thread_data*)malloc(sizeof(struct thread_data));
    if (thread_data == NULL) {
        ERROR_LOG("Failed to allocate memory for thread_data");
        return false;
    }

    thread_data->mutex = mutex;
    thread_data->wait_to_obtain_ms = wait_to_obtain_ms;
    thread_data->wait_to_release_ms = wait_to_release_ms;
    thread_data->thread_complete_success = false;

    int rc = pthread_create(thread, NULL, threadfunc, thread_data);
    if (rc != 0) {
        ERROR_LOG("pthread_create failed with code %d", rc);
        free(thread_data);
        return false;
    }

    // Small delay ensures thread starts before the test checks its state
    usleep(1000);

    return true;
}
