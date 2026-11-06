# Карточки

React и Rails API для изучения слов с интервальными повторениями.

## Запуск тестов через Docker Compose

Команды выполняются из корня проекта в Ubuntu/WSL. Нужны Docker и Docker Compose.

Поднять контейнеры (при первом запуске будут собраны образы и установлены зависимости):

```bash
docker compose up -d --build
docker compose ps
```

Дождитесь запуска PostgreSQL и приложения. Подготовить отдельную тестовую базу:

```bash
docker compose exec -T -e RAILS_ENV=test -e DATABASE_URL=postgres://postgres:password@db:5432/myapp_test web bin/rails db:prepare
```

Во всех командах тестов Rails явно указана база `myapp_test`. Не подставляйте сюда development/production URL: тесты очищают тестовые таблицы. Словарь для проверок создаётся самими тестами; загружать рабочий словарь вручную не нужно.

### Все тесты

Rails (модели, HTTP API, пользовательские сценарии и Action Cable):

```bash
docker compose exec -T -e RAILS_ENV=test -e DATABASE_URL=postgres://postgres:password@db:5432/myapp_test -e PARALLEL_WORKERS=1 web bin/rails test
```

React (интеграционные сценарии Vitest/jsdom и тесты очередей/подписок Node.js):

```bash
docker compose exec -T frontend npm test
```

### Только интеграционные сценарии

Все HTTP-сценарии и проверки каналов:

```bash
docker compose exec -T -e RAILS_ENV=test -e DATABASE_URL=postgres://postgres:password@db:5432/myapp_test -e PARALLEL_WORKERS=1 web bin/rails test test/integration test/controllers test/channels
```

Только React-интеграция:

```bash
docker compose exec -T frontend npm run test:integration
```

Один сценарий Rails по имени:

```bash
docker compose exec -T -e RAILS_ENV=test -e DATABASE_URL=postgres://postgres:password@db:5432/myapp_test -e PARALLEL_WORKERS=1 web bin/rails test test/integration/learning_workflow_test.rb -n /spaced/
```

Один сценарий React по имени:

```bash
docker compose exec -T frontend npm run test:integration -- -t "null feedback"
```

### Что проверяется

- Регистрация, вход, cookie сессии, выход и запрет доступа гостю.
- Создание колоды, копирование записи словаря, направление перевода, удаление карточки и прогресса.
- Полное занятие: оценки, уровни, интервалы, дневная цель, история и точность.
- Переход в «Выучено» после трёх оценок «Легко» в дни повторения и сброс после «Забыл».
- Тест с четырьмя различными переводами и сохранение результата сессии.
- Запрет чтения и изменения чужих колод, карточек и сессий.
- Профиль, валидация настроек и подсчёт новых карточек на границе суток.
- Личные каналы Action Cable, отклонение гостей и отозванных сессий, события после сохранения.
- React: загрузка и пустая очередь без падения при `feedback = null`, ответ и переход «Далее», сохранение результата при событии, завершение в другой вкладке, переподключение, ошибка API и повторная попытка, клавиатура и блокировка повторной отправки, удаление колоды.

Rails интеграция обращается к настоящим маршрутам, контроллерам и PostgreSQL внутри тестового процесса. React интеграция монтирует страницы с настоящими хуками, контекстом авторизации и роутером; HTTP и транспорт Action Cable заменены управляемыми ответами и событиями. Это не браузерный E2E-тест настоящего WebSocket между двумя устройствами.

Успешный запуск завершается кодом 0; Rails выводит `0 failures, 0 errors`, Vitest и Node.js — пройденные тесты. Изолированные React-тесты можно запускать без Rails и PostgreSQL: `cd frontend && npm ci --legacy-peer-deps && npm test` (Node.js 20.19+).