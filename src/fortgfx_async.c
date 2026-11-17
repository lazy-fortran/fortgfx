/* Own one initialization thread until its result has been joined. */
#include <stdlib.h>
#if defined(__linux__) && !defined(__EMSCRIPTEN__)
#include <pthread.h>
#include <stdatomic.h>
typedef struct {
  pthread_t thread;
  int (*work)(void *);
  void *data;
  atomic_int state;
} task;
static void *run(void *opaque) {
  task *t = opaque;
  int result = t->work(t->data);
  atomic_store_explicit(&t->state, result, memory_order_release);
  return NULL;
}
void *fortgfx_start(int (*work)(void *), void *data) {
  task *t = calloc(1, sizeof *t);
  if (!t)
    return NULL;
  t->work = work;
  t->data = data;
  atomic_init(&t->state, 0);
  if (pthread_create(&t->thread, NULL, run, t)) {
    free(t);
    return NULL;
  }
  return t;
}
int fortgfx_ready(void *opaque) {
  task *t = opaque;
  return t ? atomic_load_explicit(&t->state, memory_order_acquire) : -1;
}
int fortgfx_finish(void *opaque, void **data) {
  task *t = opaque;
  if (!t) {
    *data = NULL;
    return -1;
  }
  pthread_join(t->thread, NULL);
  int result = atomic_load_explicit(&t->state, memory_order_acquire);
  *data = t->data;
  free(t);
  return result;
}
#else
void *fortgfx_start(int (*work)(void *), void *data) {
  (void)work;
  (void)data;
  return NULL;
}
int fortgfx_ready(void *opaque) {
  (void)opaque;
  return -1;
}
int fortgfx_finish(void *opaque, void **data) {
  (void)opaque;
  *data = NULL;
  return -1;
}
#endif
