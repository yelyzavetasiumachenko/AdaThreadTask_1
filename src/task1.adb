pragma Style_Checks (Off);
with Ada.Text_IO;
with Ada.Numerics.Float_Random; -- Пакет для генерації випадкових чисел
with Ada.Real_Time;             -- Пакет для точного таймера (секундоміра)

procedure Task1 is
   use Ada.Real_Time; -- Робимо доступними операції з часом

   -- === ПАРАМЕТРИ ПРОГРАМИ ===
   Num_Threads : constant Integer := 8;
   Step_Value  : constant Long_Long_Integer := 10;
   -- ==========================

   type Stop_Flags is array (1 .. Num_Threads) of Boolean;
   pragma Atomic_Components(Stop_Flags);
   Can_Stop : Stop_Flags := (others => False);

   -- Масив для зберігання випадкового часу роботи (у секундах)
   type Time_Array is array (1 .. Num_Threads) of Duration;
   Stop_Times : Time_Array;

   -- Оголошення керуючого потоку
   task type Break_Thread is
      entry Start;
   end Break_Thread;

   -- Оголошення робочого потоку (тепер він приймає і свій запланований час)
   task type Main_Thread is
      entry Start_Task (Id : Integer; Step : Long_Long_Integer; Planned_Time : Duration);
   end Main_Thread;

   -- Реалізація логіки керуючого потоку (Аналог Stopwatch з C#)
   task body Break_Thread is
      Start_Time    : Time;
      Elapsed       : Time_Span;
      Elapsed_Dur   : Duration;
      Stopped_Count : Integer := 0;
   begin
      accept Start;
      
      -- Запускаємо секундомір
      Start_Time := Clock;

      -- Працюємо, поки не зупинимо всі потоки
      while Stopped_Count < Num_Threads loop
         -- Визначаємо, скільки часу пройшло від старту
         Elapsed := Clock - Start_Time;
         Elapsed_Dur := To_Duration(Elapsed);

         for I in 1 .. Num_Threads loop
            -- Якщо потік ще не зупинено І його час вже вийшов
            if not Can_Stop(I) and then Elapsed_Dur >= Stop_Times(I) then
               Can_Stop(I) := True;
               Stopped_Count := Stopped_Count + 1;
            end if;
         end loop;

         -- Мікро-пауза (50 мс), щоб не завантажувати процесор порожніми перевірками
         delay 0.05;
      end loop;
   end Break_Thread;

   -- Реалізація логіки робочого потоку
   task body Main_Thread is
      My_Id        : Integer;
      My_Step      : Long_Long_Integer;
      My_Time      : Duration;
      Sum          : Long_Long_Integer := 0;
      Current_Term : Long_Long_Integer := 0;
      Count        : Long_Long_Integer := 0;
   begin
      accept Start_Task (Id : Integer; Step : Long_Long_Integer; Planned_Time : Duration) do
         My_Id   := Id;
         My_Step := Step;
         My_Time := Planned_Time;
      end Start_Task;

      loop
         Sum := Sum + Current_Term;
         Current_Term := Current_Term + My_Step;
         Count := Count + 1;

         exit when Can_Stop(My_Id);
      end loop;

      -- Вивід результатів
      Ada.Text_IO.Put_Line ("[STOPPED] Thread #" & Integer'Image(My_Id) &
                            " | Sum:" & Long_Long_Integer'Image(Sum) &
                            " | Count:" & Long_Long_Integer'Image(Count));
   end Main_Thread;

   -- Створення реальних об'єктів
   Workers    : array (1 .. Num_Threads) of Main_Thread;
   Controller : Break_Thread;
   
   -- Об'єкт-генератор випадкових чисел
   Gen        : Ada.Numerics.Float_Random.Generator;

begin
   -- Ініціалізуємо генератор
   Ada.Numerics.Float_Random.Reset(Gen);

   Ada.Text_IO.Put_Line ("--- INITIALIZING THREADS ---");

   for I in 1 .. Num_Threads loop
      declare
         -- Отримуємо випадкове число від 0.0 до 1.0
         Rnd_Val : Float := Ada.Numerics.Float_Random.Random(Gen);
         Secs : Float := 0.5 + (Rnd_Val * 2.0); -- Випадковий час від 0.5 до 2.5 секунд
      begin
         -- Зберігаємо час у масив (перетворюємо Float у спеціальний тип часу Duration)
         Stop_Times(I) := Duration(Secs);

        Ada.Text_IO.Put_Line("Starting thread" & Integer'Image(I) &
                              ". Planned time: " & Duration'Image(Stop_Times(I)) & " s.");

         Workers(I).Start_Task(I, Step_Value, Stop_Times(I));
      end;
   end loop;

   Ada.Text_IO.Put_Line ("");

   -- Даємо команду керуючому потоку увімкнути секундомір
   Controller.Start;

end Task1;

























--  -- Вимикаємо строгу перевірку стилю (пробіли, відступи)
--  pragma Style_Checks (Off); 
--  with Ada.Text_IO; -- Підключаємо бібліотеку для виводу тексту на екран

--  procedure Task1 is
--     -- === ПАРАМЕТРИ ПРОГРАМИ ===
--     Num_Threads : constant Integer := 8;               -- Загальна кількість робочих потоків
--     Step_Value  : constant Long_Long_Integer := 10;     -- Крок послідовності (0, 10, 20...)
--     Delay_Sec   : constant Duration := 0.2;            -- Інтервал часу між зупинкою кожного наступного потоку
--     -- ==========================

--     -- Створюємо тип масиву для прапорців зупинки
--     type Stop_Flags is array (1 .. Num_Threads) of Boolean;
--     -- pragma Atomic_Components гарантує, що кожен потік одразу бачить зміни в масиві
--     pragma Atomic_Components(Stop_Flags);
   
--     -- Масив, де для кожного потоку зберігається статус: працювати (False) чи зупинитися (True)
--     Can_Stop : Stop_Flags := (others => False);

--     -- Оголошення типу керуючого потоку (Controller)
--     task type Break_Thread is
--        entry Start; -- Точка входу для запуску відліку часу
--     end Break_Thread;

--     -- Оголошення типу робочого потоку (Worker)
--     task type Main_Thread is
--        -- Точка входу для передачі індивідуальних параметрів (номер потоку та крок)
--        entry Start_Task (Id : Integer; Step : Long_Long_Integer);
--     end Main_Thread;

--     -- Реалізація логіки керуючого потоку
--     task body Break_Thread is
--     begin
--        accept Start; -- Чекаємо сигналу від головної процедури
      
--        -- Цикл, який по черзі зупиняє кожен робочий потік
--        for I in 1 .. Num_Threads loop
--           delay Delay_Sec;    -- Чекаємо заданий проміжок часу (напр. 0.2 сек)
--           Can_Stop(I) := True; -- Змінюємо прапорець для конкретного потоку на "зупинити"
--        end loop;
--     end Break_Thread;

--     -- Реалізація логіки робочого потоку
--     task body Main_Thread is
--        My_Id        : Integer;           -- Власний номер потоку
--        My_Step      : Long_Long_Integer; -- Крок послідовності
--        Sum          : Long_Long_Integer := 0; -- Змінна для накопичення суми
--        Current_Term : Long_Long_Integer := 0; -- Поточний елемент послідовності
--        Count        : Long_Long_Integer := 0; -- Лічильник використаних елементів
--     begin
--        -- Синхронізація: отримуємо параметри перед початком роботи
--        accept Start_Task (Id : Integer; Step : Long_Long_Integer) do
--           My_Id   := Id;
--           My_Step := Step;
--        end Start_Task;

--        -- Основний цикл обчислень
--        loop
--           Sum := Sum + Current_Term;         -- Додаємо число до суми
--           Current_Term := Current_Term + My_Step; -- Збільшуємо число на крок
--           Count := Count + 1;                -- Рахуємо кількість операцій
         
--           -- Перевірка умови виходу: чи надійшов сигнал зупинки саме для цього Id
--           exit when Can_Stop(My_Id);
--        end loop;

--        -- Вивід результатів після виходу з циклу
--        Ada.Text_IO.Put_Line ("Thread #" & Integer'Image(My_Id) &
--                              " | Sum:" & Long_Long_Integer'Image(Sum) &
--                              " | Count:" & Long_Long_Integer'Image(Count));
--     end Main_Thread;

--     -- Створюємо реальні об'єкти: масив робочих потоків та один керуючий потік
--     Workers    : array (1 .. Num_Threads) of Main_Thread;
--     Controller : Break_Thread;

--  begin
--     -- 1. Спочатку ініціалізуємо всі робочі потоки, передаючи їм Id та Крок
--     for I in 1 .. Num_Threads loop
--        Workers(I).Start_Task(I, Step_Value);
--     end loop;

--     -- 2. Запускаємо керуючий потік, який почне відлік часу для зупинки
--     Controller.Start;

--     -- Головна процедура завершується, коли всі завдання (tasks) виконають свою роботу
--  end Task1;