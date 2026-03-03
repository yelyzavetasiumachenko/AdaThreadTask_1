-- Вимикаємо строгу перевірку стилю (пробіли, відступи)
pragma Style_Checks (Off); 
with Ada.Text_IO; -- Підключаємо бібліотеку для виводу тексту на екран

procedure Task1 is
   -- === ПАРАМЕТРИ ПРОГРАМИ ===
   Num_Threads : constant Integer := 25;               -- Загальна кількість робочих потоків
   Step_Value  : constant Long_Long_Integer := 10;     -- Крок послідовності (0, 10, 20...)
   Delay_Sec   : constant Duration := 0.2;            -- Інтервал часу між зупинкою кожного наступного потоку
   -- ==========================

   -- Створюємо тип масиву для прапорців зупинки
   type Stop_Flags is array (1 .. Num_Threads) of Boolean;
   -- pragma Atomic_Components гарантує, що кожен потік одразу бачить зміни в масиві
   pragma Atomic_Components(Stop_Flags);
   
   -- Масив, де для кожного потоку зберігається статус: працювати (False) чи зупинитися (True)
   Can_Stop : Stop_Flags := (others => False);

   -- Оголошення типу керуючого потоку (Controller)
   task type Break_Thread is
      entry Start; -- Точка входу для запуску відліку часу
   end Break_Thread;

   -- Оголошення типу робочого потоку (Worker)
   task type Main_Thread is
      -- Точка входу для передачі індивідуальних параметрів (номер потоку та крок)
      entry Start_Task (Id : Integer; Step : Long_Long_Integer);
   end Main_Thread;

   -- Реалізація логіки керуючого потоку
   task body Break_Thread is
   begin
      accept Start; -- Чекаємо сигналу від головної процедури
      
      -- Цикл, який по черзі зупиняє кожен робочий потік
      for I in 1 .. Num_Threads loop
         delay Delay_Sec;    -- Чекаємо заданий проміжок часу (напр. 0.2 сек)
         Can_Stop(I) := True; -- Змінюємо прапорець для конкретного потоку на "зупинити"
      end loop;
   end Break_Thread;

   -- Реалізація логіки робочого потоку
   task body Main_Thread is
      My_Id        : Integer;           -- Власний номер потоку
      My_Step      : Long_Long_Integer; -- Крок послідовності
      Sum          : Long_Long_Integer := 0; -- Змінна для накопичення суми
      Current_Term : Long_Long_Integer := 0; -- Поточний елемент послідовності
      Count        : Long_Long_Integer := 0; -- Лічильник використаних елементів
   begin
      -- Синхронізація: отримуємо параметри перед початком роботи
      accept Start_Task (Id : Integer; Step : Long_Long_Integer) do
         My_Id   := Id;
         My_Step := Step;
      end Start_Task;

      -- Основний цикл обчислень
      loop
         Sum := Sum + Current_Term;         -- Додаємо число до суми
         Current_Term := Current_Term + My_Step; -- Збільшуємо число на крок
         Count := Count + 1;                -- Рахуємо кількість операцій
         
         -- Перевірка умови виходу: чи надійшов сигнал зупинки саме для цього Id
         exit when Can_Stop(My_Id);
      end loop;

      -- Вивід результатів після виходу з циклу
      Ada.Text_IO.Put_Line ("Thread #" & Integer'Image(My_Id) &
                            " | Sum:" & Long_Long_Integer'Image(Sum) &
                            " | Count:" & Long_Long_Integer'Image(Count));
   end Main_Thread;

   -- Створюємо реальні об'єкти: масив робочих потоків та один керуючий потік
   Workers    : array (1 .. Num_Threads) of Main_Thread;
   Controller : Break_Thread;

begin
   -- 1. Спочатку ініціалізуємо всі робочі потоки, передаючи їм Id та Крок
   for I in 1 .. Num_Threads loop
      Workers(I).Start_Task(I, Step_Value);
   end loop;

   -- 2. Запускаємо керуючий потік, який почне відлік часу для зупинки
   Controller.Start;

   -- Головна процедура завершується, коли всі завдання (tasks) виконають свою роботу
end Task1;