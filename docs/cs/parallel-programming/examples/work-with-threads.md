# Как работать с потоками?

В линуксе всё основано на POSIX Threads

## В С через API POSIX

| Операция | POSIX |
|---|---|
| Создание | `pthread_create()` |
| Ожидание завершения | `pthread_join()` |
| Захват мьютекса | `pthread_mutex_lock()` |
| Освобождение мьютекса | `pthread_mutex_unlock()` |

```c
int pthread_create( 
    pthread_t *thread,  // идентификатор потока
    const pthread_attr_t *attr,
    void *(*start_routine)(void *),  // ptr to func
    void *arg
);
```

## Java

- Наследование от `Thread`
- Реализация `Runnable` (предпотчительно)
- Остальное привычно: `start()`, `join()`

```java
public class IntegrateRunnable implements Runnable {

    public IntegrateTask task;

    @Override
    public void run() {
        task.res = 0;
        for (double x = task.from; x < task.to - 1E-13 * task.to; x += task.step) {
            task.res += task.f(x) * task.step;
        }
    }
}
```

### Почему наследование `Runnable` лучше?

1. Теряем возможность переиспользовать задачу и созданный поток, так как сильно связываем их
2. Меньше возможности для разведения иерархии OOP
3. [Агрегация вместо наследования](../../oop/objects-connectivity.md)

### Когда наследоваться от `Thread`

Если хотим обогатить функциональность потока, например сделать самый приоритетный поток
