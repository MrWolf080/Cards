# Карточки

Веб-приложение для изучения английских и русских слов с интервальными повторениями. Соберите колоду из встроенного словаря или своих карточек, пройдите занятие и отслеживайте прогресс.

- **Колоды и карточки.** Выберите направление EN → RU или RU → EN. Добавляйте слова из подборки или вручную. Карточки можно искать, редактировать и удалять. При редактировании сохраняются прогресс и история ответов.
- **Изучение.** Переверните карточку и оцените, насколько хорошо запомнили перевод. Оценка определяет дату следующего повторения.
- **Тест.** Выберите перевод из вариантов, составленных из карточек той же колоды. Для запуска нужно минимум четыре карточки.
- **Прогресс.** Панель показывает, сколько карточек пора повторить. Статистика показывает точность, серию дней и историю занятий. В профиле можно изменить дневную цель по новым карточкам и часовой пояс.
- **Синхронизация и напоминания.** Изменения в колодах и занятиях подхватываются в других вкладках через WebSocket. При настроенном SMTP приложение отправляет напоминания о повторениях.

## Быстрый запуск

Нужны Docker и Docker Compose. Выполняйте команды в корне проекта. На Windows используйте терминал WSL.

```bash
docker compose up -d --build
docker compose ps
```

Когда контейнеры запустятся, загрузите словарь:

```bash
docker compose exec -T web bin/rails db:seed
```

Откройте [http://localhost:5173](http://localhost:5173), зарегистрируйтесь и создайте первую колоду. Rails API доступен на порту 3000. Vite проксирует запросы к API и WebSocket.

## Как устроен проект

| Каталог | Что в нём |
| --- | --- |
| `frontend/` | React, React Router и Vite. Страницы колод, занятий, статистики и профиля |
| `app/controllers/api/v1/` | Rails API. Авторизация по cookie сессии и проверка владельца данных |
| `app/models/`, `db/` | Модели, миграции PostgreSQL, схема и словарные батчи |
| `app/channels/` | Личные каналы Action Cable для обновлений в открытых вкладках |
| `app/jobs/`, `app/mailers/` | Задачи Solid Queue и письма Action Mailer |
| `test/`, `frontend/src/test/` | Тесты Rails и интеграционные тесты React |

В режиме «Карточки» доступны четыре оценки. Уровень хранится отдельно для каждой карточки и ограничен диапазоном от 0 до 5.

| Оценка | Изменение уровня | Следующий показ |
| --- | --- | --- |
| Забыл | Сброс до 0 | Через 1 день |
| Трудно | Уровень остаётся прежним | Через 2 дня |
| Хорошо | +1 | Через 4 дня |
| Легко | +2 | Через 7 дней |

При уровне 5 карточка получает статус «Выучено», а интервал увеличивается до 14 дней. Правильный ответ в тесте соответствует оценке «Хорошо», ошибочный — «Забыл».

## Словарь

На чистой базе батчи загружают 50 000 уникальных пар «слово — перевод». Батчи 006–054 содержат переводы из [KOReader Dicts EN→RU](https://danielgregorini.github.io/koreader-dicts/en/en-ru/), выпуск от 11 сентября 2026 года, на основе English Wiktionary (через Kaikki/Wiktextract) и Princeton WordNet 3.0. Переводы в этих батчах распространяются по [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). При импорте исходных данных для батчей извлечены слова, переводы и части речи, сняты знаки ударения, удалены повторы и добавлен ранг по частоте английских слов в корпусе примеров.

Примеры из корпуса OPUS Tatoeba v2023-04-12 распространяются по [CC BY 2.0 FR](https://creativecommons.org/licenses/by/2.0/fr/). Ссылки на обе фразы указаны в `source`. Если подходящая пара предложений не найдена, поля `example_en` и `example_ru` пусты. Ссылка на публикацию корпуса: J. Tiedemann, *Parallel Data, Tools and Interfaces in OPUS*, LREC 2012.

Команда `docker compose exec -T web bin/rails db:seed` добавляет записи и обновляет существующие по паре «слово — перевод».

## Напоминания по email

Solid Queue проверяет расписание каждый час в development и production. После 09:00 по часовому поясу пользователя он отправляет одно письмо за местный день, если есть карточки с датой повторения на сегодня.

В development через Docker Compose контейнер `web` подготавливает отдельную базу очереди и запускает Solid Queue вместе с Puma.

Для отправки через внешний SMTP из локального Docker создайте файл `.env` в корне проекта. Git игнорирует этот файл. Подставьте настройки вашего провайдера и подтверждённый адрес отправителя.

```dotenv
SMTP_ADDRESS=smtp.example.com
SMTP_PORT=587
SMTP_SECURITY=starttls
SMTP_USERNAME=sender@example.com
SMTP_PASSWORD='ваш SMTP-токен или пароль приложения'
MAIL_FROM=sender@example.com
APP_URL=https://cards.example.com
```

Если провайдер требует TLS с момента подключения, укажите `SMTP_SECURITY=tls` и его SMTP-порт. `APP_URL` должен быть доступен получателям письма. После заполнения пересоздайте контейнер командой `docker compose up -d db web`.

Чтобы проверить отправку через внешний SMTP, подставьте свой email вместо `preview@example.test` и выполните команду:

```bash
docker compose exec -T web bin/rails runner 'ReviewReminderMailer.with(user: User.new(email_address: "preview@example.test"), count: 2).daily.deliver_now'
```

Примените `bin/rails db:prepare` и запустите Solid Queue через `bin/jobs` или существующий режим `SOLID_QUEUE_IN_PUMA=true`. Передайте веб-приложению и обработчику задач переменные `SMTP_ADDRESS`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAIL_FROM` и `APP_URL` (публичный адрес фронтенда). Порт SMTP задаётся через `SMTP_PORT`, по умолчанию 587. Без `SMTP_ADDRESS` рассылка в production выключена.

## Тесты

Запустите контейнеры по инструкции выше. Для Rails подготовьте отдельную базу `myapp_test`. Тестовые данные создаются при запуске сценариев.

```bash
docker compose exec -T -e RAILS_ENV=test -e DATABASE_URL=postgres://postgres:password@db:5432/myapp_test web bin/rails db:prepare
```

Весь набор Rails и тесты фронтенда:

```bash
docker compose exec -T -e RAILS_ENV=test -e DATABASE_URL=postgres://postgres:password@db:5432/myapp_test -e PARALLEL_WORKERS=1 web bin/rails test
docker compose exec -T frontend npm test
```

Только пользовательские сценарии из `test/integration` и интеграционные тесты React:

```bash
docker compose exec -T -e RAILS_ENV=test -e DATABASE_URL=postgres://postgres:password@db:5432/myapp_test -e PARALLEL_WORKERS=1 web bin/rails test test/integration
docker compose exec -T frontend npm run test:integration
```

Для запуска одного Rails-файла укажите его путь после `bin/rails test`. Например, `test/integration/learning_workflow_test.rb`. Rails-тесты проходят через HTTP-маршруты и PostgreSQL. React-тесты запускаются в jsdom с имитацией HTTP и событий Action Cable.
