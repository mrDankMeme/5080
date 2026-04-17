# AppTemplate

Все ключевые данные централизованы в:
- `Infrastructure/Configuration/AppTemplateConfiguration.swift`

Шаблонное iOS-приложение (SwiftUI) для быстрого старта проектов с:
- онбордингом (3 слайда),
- paywall,
- подписками через Adapty,
- экраном настроек,
- базовым таб-баром с 3 сценами.

## 1) Что реализовано

1. Первый запуск:
- показывается онбординг из 3 слайдов;
- после 3-го слайда paywall выезжает как продолжение онбординга.

2. Главный экран:
- 3 базовые сцены в таб-баре: `Сцена 1`, `Сцена 2`, `Сцена 3`;
- в `Сцена 1` есть кнопка перехода в настройки.

3. Экран настроек:
- `Управление подпиской` (открывает paywall);
- `Восстановить покупки` (реальный restore через Adapty);
- `Политика конфиденциальности` (внутри приложения в WebView);
- `Условия использования` (внутри приложения в WebView);
- если подписка активна, первая строка показывает формат `Подписка: <тип>`.

4. Paywall:
- грузит продукты из placement `main`;
- поддерживает покупку и восстановление;
- кнопка закрытия появляется через 5 секунд;
- при закрытии первичного paywall (после онбординга) экран уезжает вниз.

## 2) Технологии

- SwiftUI
- MVVM
- Clean Architecture
- SOLID
- POP (Protocol-Oriented boundaries в Domain/Data)
- DI через Swinject
- Adapty SDK
- StoreKit Configuration (`Debug.storekit`) для локального теста покупок

## 3) Архитектура и слои (очень простое объяснение)

### 3.1 `Application` — «точка сборки приложения»

Зачем нужен:
- чтобы в одном месте собрать приложение и его зависимости;
- чтобы экран не создавал зависимости сам вручную.

Что внутри:
- старт приложения (`AppTemplateApp.swift`);
- создание DI-контейнера (`AppAssembler.swift`);
- регистрации сервисов и ViewModel (`ServicesAssembly.swift`).
- сборка `AppFlowView` через явные зависимости в `init` (без service locator во View).

Что нельзя сюда класть:
- UI-верстку экранов;
- бизнес-правила подписок.

### 3.2 `Presentation` — «то, что видит пользователь»

Зачем нужен:
- чтобы хранить экраны и их состояние;
- чтобы изолировать UI от бизнес-логики.

Что внутри:
- `View` и `ViewModel` сцен (`OnboardingScene`, `PaywallScene`, `SettingsScene` и т.д.);
- состояние кнопок, алертов, текущего слайда, выбранного таба.
- экраны получают уже собранные зависимости через init, а не через `.resolve(...)` внутри View.

Что нельзя сюда класть:
- прямой код работы с Adapty SDK;
- сетевую/дата-логику;
- сложные доменные правила.

### 3.3 `Domain` — «правила приложения»

Зачем нужен:
- чтобы описать логику на уровне приложения, а не конкретной библиотеки;
- чтобы код было легко менять (например, заменить Adapty на другой сервис).

Что внутри:
- доменные модели (`SubscriptionPlan`, `PaywallData` и т.д.);
- протокол репозитория (`BillingRepository`);
- use case протоколы (`...UseCaseProtocol`) и их реализации.

Что нельзя сюда класть:
- SwiftUI-код;
- детали конкретного SDK (Adapty типы).

### 3.4 `Data` — «как мы реально получаем данные»

Зачем нужен:
- чтобы реализовать контракты из `Domain`;
- чтобы именно здесь была связь с внешним SDK/источником данных.

Что внутри:
- `AdaptyBillingRepository` (реальная работа с Adapty);
- внутри репозитория разделены роли:
- `AdaptyClientProtocol` (внешний SDK),
- `BillingStateStoreProtocol` (кеш и fallback user id);
- ресурсы биллинга (`Debug.storekit`).

Что нельзя сюда класть:
- верстку экранов;
- регистрацию DI.

### 3.5 `Infrastructure` — «конфиги и константы»

Зачем нужен:
- чтобы ключи, ссылки и тексты не были разбросаны по проекту;
- чтобы изменения делались в одном месте.

Что внутри:
- `AppTemplateConfiguration.swift`:
- Adapty key, placement, product IDs;
- внешние ссылки;
- текстовые копирайты.

Что нельзя сюда класть:
- UI-компоненты;
- use cases.

### 3.6 `Core` — «общие инструменты и дизайн-система»

Зачем нужен:
- чтобы переиспользовать кнопки, футер, цвета, шрифты, scale;
- чтобы все экраны выглядели единообразно.

Что внутри:
- `Tokens` (цвета/шрифты/радиусы);
- общие UI-компоненты;
- `.scale` утилиты;
- DI helper для `Environment`.

Что нельзя сюда класть:
- бизнес-логику конкретной сцены;
- код, завязанный только на один экран.

## 4) Структура проекта

Корень кода:
- `AppTemplate/AppTemplate`

Основные директории:
- `Application`
- `Presentation`
- `Domain`
- `Data`
- `Infrastructure`
- `Core`
- `Assets.xcassets`

## 5) Главный пользовательский flow

1. `AppTemplateApp` резолвит корневые ViewModel в composition root и передает их в `AppFlowView` через `init`.
2. `AppFlowViewModel` читает состояние из `UserDefaults`:
- завершен ли онбординг;
- завершен ли первичный paywall;
- активна ли подписка.
3. Если онбординг не завершен, показывается `Onboarding`.
4. После 3-го слайда:
- если подписка уже восстановлена, paywall пропускается;
- иначе показывается первичный paywall.
5. После завершения flow показывается `RootTabView`.

## 6) Где хранятся «живые» данные

Все ключевые данные централизованы в:
- `Infrastructure/Configuration/AppTemplateConfiguration.swift`

### 6.1 Adapty

`AppTemplateConfiguration.Adapty`:
- `apiKey`
- `mainPlacementID` (сейчас используется только `main`)
- `accessLevelKey`
- `subscriptionProductIDs`

### 6.2 Внешние ссылки

`AppTemplateConfiguration.External`:
- privacy policy URL
- terms of use URL
- support email
- manage subscription URL
- support form URL
- app store URL

В текущем UI реально используются privacy/terms.

### 6.3 Тексты

`AppTemplateConfiguration.Copy`:
- тексты слайдов онбординга,
- тексты paywall,
- тексты кнопок/алертов,
- тексты настроек.

## 7) Как работает биллинг

1. `BillingRepository` в Domain задает контракт.
2. `AdaptyBillingRepository` в Data реализует этот контракт через Adapty SDK.
3. Use cases в VM подключаются по протоколам (`...UseCaseProtocol`), а не по concrete типам.
4. После покупки/restore обновляется состояние подписки.
5. Кеш подписки хранится в `UserDefaults`.

Ключи кеша:
- `template_adapty_cached_is_subscribed`
- `template_adapty_cached_active_product_id`
- `template_adapty_fallback_user_id`

## 8) StoreKit: что это и как им пользоваться

Файл:
- `AppTemplate/Data/Billing/Resources/Debug.storekit`

### 8.1 Что это

`Debug.storekit` — локальная симуляция покупок для debug/симулятора.
Это удобно для быстрых проверок purchase/restore без реальной покупки.

Сейчас в файле добавлены подписки:
- `week_6.99_nottrial`
- `yearly_49.99_nottrial`

### 8.2 Где подключен

В схеме Xcode:
- `AppTemplate.xcodeproj/xcshareddata/xcschemes/AppTemplate.xcscheme`
- `LaunchAction -> StoreKitConfigurationFileReference`

### 8.3 Как проверить поведение без локальной StoreKit-симуляции

1. Откройте Xcode -> `Product -> Scheme -> Edit Scheme...`
2. Выберите `Run`.
3. В StoreKit Configuration выберите `None` вместо `Debug.storekit`.
4. Запустите приложение заново.

Так вы исключите влияние локальной StoreKit-конфигурации при проверке сценариев с реальным backend Adapty.

## 9) Шпаргалка: где менять что

1. Тексты слайдов онбординга:
- `Infrastructure/Configuration/AppTemplateConfiguration.swift` -> `Copy.onboardingSlides`

2. Ссылки privacy/terms:
- `Infrastructure/Configuration/AppTemplateConfiguration.swift` -> `External`

3. Adapty key / placement / product IDs:
- `Infrastructure/Configuration/AppTemplateConfiguration.swift` -> `Adapty`

4. Логика paywall:
- `Presentation/PaywallScene/PaywallViewModel.swift`

5. UI paywall:
- `Presentation/PaywallScene/PaywallView.swift`

6. Логика настроек:
- `Presentation/SettingsScene/SettingsViewModel.swift`

7. Строки/модель rows настроек:
- `Presentation/SettingsScene/SettingsRow.swift`

8. Главный flow:
- `Presentation/AppFlow/AppFlowView.swift`
- `Presentation/AppFlow/AppFlowViewModel.swift`

9. Токены (цвета/шрифты/радиусы):
- `Core/DesignSystem/Tokens.swift`

10. DI-регистрации:
- `Application/ServicesAssembly.swift`

## 10) Правила проекта

1. Все размеры/отступы/радиусы указываются с `.scale`.
2. Цвета и шрифты берутся из `Tokens`.
3. Системные шрифты напрямую не используем (`.system(...)` в экранах запрещен): используем только `Tokens.Font`.
4. DI настраивается через `Swinject` в `ServicesAssembly`.
5. Слои не смешиваются.
6. Во View не добавляется бизнес-логика.

## 11) FAQ

1. Почему в настройках видно `Подписка: Годовая` или `Подписка: Недельная`?
- Тип определяется по `activeProductID`, полученному из профиля Adapty.

2. Почему кнопка закрытия paywall появляется не сразу?
- По текущей логике она показывается через 5 секунд.

3. Почему restore может показать неуспех?
- Когда Adapty возвращает, что восстанавливать нечего, UI показывает сообщение о неуспешном восстановлении.

## 12) Документ для разработчиков

Отдельный файл с правилами разработки:
- `README.dev.md`
