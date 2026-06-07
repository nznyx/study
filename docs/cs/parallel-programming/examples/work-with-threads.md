# Как работать с потоками?

В линуксе всё основано на POSIX Threads

## Завершение потока

Убивать поток не надо, могут быть не освобождённые ресурсы. Поэтому хотим вежливо намекнуть потоку, что ему пора уходить

## В С через API POSIX

| Операция | POSIX |
|---|---|
| Создание | `pthread_create()` |
| Ожидание завершения | `pthread_join()` |
| Захват мьютекса | `pthread_mutex_lock()` |
| Освобождение мьютекса | `pthread_mutex_unlock()` |

### Создание

```c
int pthread_create( 
    pthread_t *thread,  // идентификатор потока
    const pthread_attr_t *attr,
    void *(*start_routine)(void *),  // ptr to func
    void *arg
);
```

### Отмена выполнения

С помощью `pthread_cancel(id)` - функция выстаяляет флаг в данных потока (в `pthread` структуре), что ему пора завершиться

С помощью `pthread_testcancel()` - попробовать завершиться если просили, некоторые другие функции, например `pthread_sleep()` содержат в себе заложенную возможность остановки (являются `cancelation point`), проверяйте `man` для своей OS (по стандарту `POSIX` некоторые системные вызовы могут, но не обязаны быть `cancelation point`)

С помощью `pthread_cleanup_push(func)` - можно положить на стек функцию особождения данных, их вызовут в `cancelation point` в обратном порядке

C помощью `pthread_cleanup_pop(0|1)` - можно снять со стека функцию, `1` - срузу её вычислить, `0` - просто убрать. Нужно для уменьшения количества дубликации кода

С помощью `pthread_setcancelstate(some_flag)` - можно запретить/разрешить останавать конкретный поток. Нужно для протоколов, в которых логически необходимо вызвать нукую завершающую функцию (пример: Протокол старта измерения времени начинает работу после `fwrite("start")`, а заканчивает только после `fwrite("stop")`, в таком протоколе завершить поток после start, но перед stop некорректно, а fwrite является `cancelation point`, поэтому запращяем отменять поток на промежутке `[start, stop]`)

```text
      MAIN                     WORKER
──────────────────  ─────────────────────────────

pthread_create()
  │
  │───────────────────────> thread_func()
  │                              │
  │                              ▼
  │                    ┌───────────────────┐
  │                    │_cleanup_push(...) │
  │                    │push free function │
  │                    └─────────┬─────────┘
  │                              ▼
  │                    ┌───────────────────┐
  │                    │mutex_lock(m)      │
  │                    └─────────┬─────────┘
  │                              ▼
  │                    ┌───────────────────┐
  │                    │work with resource │
  │                    └─────────┬─────────┘
  │                              ▼
  │                    ┌────────────────────┐
  │                    │_pthread_testcancel │
  │                    └─────────┬──────────┘
  │                              ▼
pthread_cancel(id)     ┌───────────────────┐
  │                    │cancel requested?  │
  │                    └──────┬─────┬──────┘
  │                           │     │
  │                         no│     │yes
  │                           │     ▼
  │                           │ ┌───────────────────┐
  │                           │ │_cleanup_pop(1)    │
  │                           │ └─────────┬─────────┘
  │                           │           ▼
  │                           │ ┌───────────────────┐
  │                           │ │mutex_unlock(m)    │
  │                           │ └─────────┬─────────┘
  │                           │           ▼
  │                           │ ┌───────────────────┐
  │                           │ │thread exits       │
  │                           │ └───────────────────┘
  │                           │
  │                           ▼
  │                    ┌───────────────────┐
  │                    │_cleanup_pop(1)    │
  │                    │1 - pop and call   |
  │                    │0 - just pop       |
  │                    └─────────┬─────────┘
  │                              ▼
  │                    ┌───────────────────┐
  │                    │return             │
  │                    └───────────────────┘
  ▼
pthread_join(id)
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

### Отмена выполнения в Java

```java
thread.interrupt();
```

Поток сам должен периодически проверять, не попросили ли его завершиться.

#### Пример

```java
public class Worker implements Runnable {

    @Override
    public void run() {
        // Или просто .interrupted(), но он сбарасывает флаг
        while (!Thread.currentThread().isInterrupted()) {
            try {
                // Какая-то полезная работа
                System.out.println("Working...");

                /*
                * sleep() — это interruption point.
                *
                * Если поток уже был interrupted,
                * то sleep() выбросит InterruptedException.
                */
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                /*
                * Важно:
                * InterruptedException сбрасывает interrupted-флаг.
                *
                * Поэтому после catch обычно нужно снова вызвать interrupt(),
                * чтобы восстановить состояние прерывания потока.
                */
                Thread.currentThread().interrupt();
            } 
        }
        // Корректное завершение потока
        System.out.println("Worker finished");
    }
}
```

#### Использование

```java
public class Main {
    public static void main(String[] args) throws InterruptedException {
        Thread worker = new Thread(new Worker());

        worker.start();

        Thread.sleep(3000);

        // Просим поток завершиться
        worker.interrupt();

        worker.join();

        System.out.println("Main finished");
    }
}
```

#### Важно

```java
while (!Thread.currentThread().isInterrupted()) {
    Thread.sleep(1000);
}
```

- `isInterrupted()` проверяет флаг прерывания, но **не сбрасывает** его.
- `Thread.interrupted()` проверяет флаг прерывания **и сбрасывает** его.
- `sleep()`, `wait()`, `join()` и некоторые другие методы являются interruption points.
- Interruption point фактически проверяет interrupt-флаг.
- Если флаг был установлен, метод выбрасывает `InterruptedException`.
- `InterruptedException` можно поймать через `catch`.
- После `catch (InterruptedException e)` обычно нужно вызвать:

```java
Thread.currentThread().interrupt();
```

Иначе информация о том, что поток был прерван, потеряется.

#### Аналог `_setcancelstate`

**НЕТ**, только костыли, например в критеческом блоке создать новый поток, который сделает все операции и вернёт их значение родителю, об этом потоке никто не знает, поэтому никто не пошлёт ему `cancel`

## Сравнение на разных языках

В C++20 заметно улучшили стандартную поддержку многопоточности: появился `std::jthread`, который автоматически делает `join()` в деструкторе, а также механизм кооперативной остановки через `std::stop_token`. Это уменьшает количество ручного кода и снижает риск забыть `join()` или некорректно завершить поток.

| POSIX | C++ | Java |
|---|---|---|
| `pthread_create` | `std::(j)thread` | `Thread.start()` |
| `pthread_join` | `.join()` | `.join()` |
| `pthread_mutex_lock` | `mutex.lock()` | `synchronized` |
| `pthread_cancel()` | — (`C++11`) / `std::stop_token` (`C++20`) | `.interrupt()` |

> Примечание: в C++20 вместо ручного управления `std::thread` часто удобнее использовать `std::jthread`, так как он автоматически присоединяется при уничтожении и поддерживает stop-token для кооперативной остановки.
