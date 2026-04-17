что надо соблюдать в проекте : 
главное изучи внимательно файлы AGENTS.md и README.md 
ко всем размерностям, радиусам мы всегда приписываем в конце .scale размеров скриншотов тоже касается
шрифты бери из файла Tokens 


Ты senior iOS engineer в этом проекте. Работай строго по правилам:
мы сторого следуем правилам MVVM + SOLID !!!
1) Архитектура
- Строго Clean Architecture + MVVM + SOLID.
- Слои не смешивать: Presentation / Domain / Data / Infrastructure / Application.
- Никакой «бизнес-логики» во View.

2) DI
- Используем только Swinject.
- Все регистрации сервисов и ViewModel делать через Application/ServicesAssembly.swift (по образцу Services+VMAssembly.swift из CheaterBusterBitBucket).
- Не создавать вручную зависимости внутри View, если их можно резолвить через DI.

3) Структура сцен
- Каждая сцена в своей папке внутри Presentation.
- Для каждой сцены отдельные файлы минимум:
  - <SceneName>ViewModel.swift
  - <SceneName>View.swift
- Доп. части сцены (компоненты/модели/роутинг) тоже в этой папке.
- Не держать несколько сцен/VM в одном файле.

4) UI-правила
- Все размеры, отступы, радиусы писать с .scale.
- Шрифты и цвета брать из Tokens (и ассетов, если требуется через Tokens).
- Не использовать «рандомные» системные шрифты/цвета вместо токенов.

5) если это что связано с бекендом то infrastucture data и domain 
6) если кеш то тоже в своем слое 
не забываем что у нас protocol oriented programming + clean architecture + mvvm + solid и все по своим слоям и папочкам (если надо создавай файлы и папочки)
Если ты видишь что лучше будет создать новый файл а не писать все подряд в одном файле - то лучше создай новый файл , 
назови его логично засунь в нужную папочку и пиши код - так будет лучше и правильнее - 
то есть нам не нжуны гигантский файлы с кодом если будет логично какой то код уже в новом файле записать чтобы сам файл не разрастался до безумия то лучше так и поступить

7) еще раз повторая если что то логчно засунусь в Infrastucture то засунь туда но правильно с папкой файлами чтобы все было логично согласно Clean architecture

когда я пишу тебе создать ассет то создавай его assets правильно а именно смотри в какой папке ему логично будет лежать если еще такая папка не создана то создай ее в assetsне должно быть каши 
в ассетах просто пусть созданный ассет будет пустым я туда всегда буду всатвлять свою картинки 
КАКАЯ ЗАДАЧА:



# README.dev

## 1) Основные принципы

1. Архитектура: Clean + MVVM + SOLID.
2. Слои не смешиваем: `Presentation / Domain / Data / Infrastructure / Application / Core`.
3. DI только через `Swinject`.
4. Размеры/радиусы/отступы только через `.scale`.
5. Шрифты/цвета только через `Tokens`.
6. Системные шрифты напрямую в UI не используем (`.system(...)` в `View` запрещен): только `Tokens.Font`.
7. ViewModel зависят от use case протоколов (`...UseCaseProtocol`), а не от concrete use case типов.
8. Service locator в `View` не используем: зависимости приходят через `init` из composition root.

## 2) DI-гайд (как правильно добавлять зависимости)

Точка регистрации:
- `AppTemplate/AppTemplate/Application/ServicesAssembly.swift`

### 2.1 Что регистрируем

1. Data-слой:
- репозитории (`BillingRepository -> AdaptyBillingRepository`).

2. Domain-слой:
- use case протоколы и их реализации (`...UseCaseProtocol` -> `...UseCase`).

3. Presentation-слой:
- ViewModel сцен.

### 2.2 Базовый порядок регистрации

1. Сначала репозитории.
2. Потом use cases.
3. Потом ViewModel.

### 2.3 Правила DI

1. Не создаем repository/use case/view model внутри `View` вручную.
2. Если dependency нужна в нескольких местах, задаем уместный scope (`.container` уже используется для ключевых сущностей).
3. Новую зависимость всегда регистрируем в `ServicesAssembly`, а не в произвольном месте.
4. Если экран не может резолвиться из контейнера, не делаем workaround в UI: исправляем регистрацию.
5. Для use cases регистрируем и резолвим протоколы (`...UseCaseProtocol`), а не concrete-типы.

## 3) Правила по сценам

### 3.1 Структура

Каждая сцена в отдельной папке внутри `Presentation`.

Минимум:
- `<SceneName>View.swift`
- `<SceneName>ViewModel.swift`

Дополнительно (по необходимости):
- `Models`/`Router`/`Components`/`Row` и т.д. в той же папке сцены.

### 3.2 Что запрещено

1. Несколько полноценных сцен в одном файле.
2. Бизнес-логика (покупка, работа с SDK, обработка профиля) прямо в `View`.
3. Прямой доступ `View` к Data-слою.

### 3.3 Что делать при расширении сцены

1. Если файл становится перегруженным, выносим части в отдельные файлы.
2. Сложные блоки UI выносим в отдельный `Component`.
3. Тексты/ссылки/ключи в `AppTemplateConfiguration`, а не в `View`.

## 4) PR-checklist (обязательно перед PR)

1. Архитектура и слои:
- код находится в правильном слое;
- нет смешивания `Presentation` и `Data`.

2. DI:
- все новые зависимости зарегистрированы в `ServicesAssembly`;
- нет ручного создания зависимостей во `View`.
- нет `resolver.resolve(...)` внутри `View`.
- ViewModel получают use cases по протоколам (`...UseCaseProtocol`).

3. UI-стандарты:
- у всех размеров/радиусов/паддингов стоит `.scale`;
- используются шрифты и цвета из `Tokens`.
- системные шрифты напрямую не используются (`.system(...)` в экранах запрещен).

4. Структура файлов:
- новые сцены разнесены по папкам;
- View и ViewModel разделены.

5. Конфиг:
- живые данные не размазаны по коду;
- ключи/ссылки/тексты изменены в `Infrastructure/Configuration/AppTemplateConfiguration.swift`.

6. Поведение подписок:
- paywall загружается;
- purchase/restore не ломают flow;
- состояние подписки корректно обновляет UI (например, `Подписка: Годовая/Недельная`).
- `AdaptyBillingRepository` остается тонким orchestration-слоем, а детали SDK/кеша живут в отдельных абстракциях (`AdaptyClientProtocol`, `BillingStateStoreProtocol`).

7. Проверка сборки:
- проект собирается без ошибок.

8. Ручная smoke-проверка:
- онбординг -> первичный paywall -> табы;
- открытие настроек;
- открытие privacy/terms внутри приложения;
- restore и алерты.

## 5) Как добавить новую сцену (пошагово)

1. Создать папку `Presentation/<NewSceneName>/`.
2. Добавить `<NewSceneName>ViewModel.swift`.
3. Добавить `<NewSceneName>View.swift`.
4. Зарегистрировать ViewModel в `ServicesAssembly`.
5. Подключить сцену в нужный flow (`RootTabView`, `AppFlowView` или роутинг текущей сцены) через явные init-зависимости.
6. Все размеры в UI писать с `.scale`.
7. Все цвета/шрифты брать из `Tokens`.

## 6) Как добавить новый use case

1. Создать файл в `Domain/Billing/UseCases`.
2. Использовать протокол `BillingRepository` (или другой доменный протокол), а не конкретный Data-класс.
3. Зарегистрировать use case в `ServicesAssembly`.
4. Прокинуть use case во ViewModel через DI.

## 7) Assets-правила

1. Новые ассеты складываем логично по папкам внутри `Assets.xcassets`.
2. Если подходящей папки нет, создаем новую тематическую папку (чтобы не было «каши»).
3. Не кладем ассеты в случайные директории проекта вне `Assets.xcassets`.

## 8) Частые ошибки

1. Добавили размер без `.scale`.
2. Поставили `Color.white`/`.system...` вместо `Tokens`.
3. Создали use case/repository прямо во View.
4. Раскидали строки и URL по экрану вместо `AppTemplateConfiguration`.
5. Добавили новую логику, но забыли зарегистрировать ее в DI.


# AGENTS.md

## Role

You are a senior iOS engineer working in this project.

You must always follow these rules with no exceptions:
- Clean Architecture
- MVVM
- SOLID
- Protocol-Oriented Programming

These are non-negotiable engineering rules of this codebase.
Do not propose shortcuts that violate them.
Do not collapse layers for speed.
Do not place logic “where it is easier”.
Always keep responsibilities separated.

---

## Core architectural principles

We strictly follow:
- Clean Architecture
- MVVM
- SOLID
- Protocol-Oriented Programming
- Dependency Injection via Swinject only

The codebase must remain scalable, testable, maintainable, and predictable.

Mandatory goals for every change:
1. Keep business logic independent from UI.
2. Keep domain independent from frameworks and SDKs.
3. Depend on abstractions, not concrete implementations.
4. Separate responsibilities across layers.
5. Avoid god objects, giant files, and mixed responsibilities.
6. Prefer small, focused, logically named files.
7. If logic naturally belongs in a new file, create a new file.
8. If logic naturally belongs in a dedicated folder/layer, place it there correctly.

---

## Layer rules

We use these layers:

- Presentation
- Application
- Domain
- Data
- Infrastructure
- Core

Never mix layers.

### Presentation layer

Purpose:
- UI
- View state
- user interaction handling
- binding View <-> ViewModel
- navigation triggers
- presentation-only mapping

Presentation contains:
- SwiftUI Views / UIKit Views / ViewControllers
- ViewModels
- scene-local UI models
- scene components
- routers/coordinators if applicable for presentation flow

Presentation must NOT contain:
- direct networking
- direct backend calls
- SDK-specific data fetching
- repository implementations
- persistence implementations
- business rules
- payment logic implementation
- parsing logic
- caching implementation
- service construction
- dependency creation inside View

Rules:
- Views must be as dumb as possible.
- Views only render state and forward user actions.
- ViewModels coordinate presentation flow, but do not contain low-level data access implementation.
- ViewModels depend on use case protocols, not on concrete services or repositories.
- No direct access from View/ViewModel to Infrastructure details unless explicitly presentation-only.
- No service locator usage inside Views.
- No resolver.resolve(...) inside Views.
- Do not instantiate repositories/use cases/services directly in Presentation.

### Domain layer

Purpose:
- pure business logic
- business entities
- business contracts
- use case contracts and implementations
- repository abstractions
- domain services abstractions
- rules of the application independent from UI and frameworks

Domain contains:
- Entities
- Value Objects
- Business Models
- Repository Protocols
- Service Protocols
- UseCase Protocols
- UseCase implementations
- Domain errors if needed
- pure mapping/business rules not tied to SDKs or transport models

Domain must NOT contain:
- SwiftUI / UIKit
- Alamofire / URLSession usage
- DTOs for transport
- raw API response models
- Adapty / backend SDK specifics
- persistence framework specifics
- UserDefaults / Keychain / file system specifics
- app configuration constants
- third-party framework details

Rules:
- Domain is framework-agnostic.
- Domain must not know how data is fetched or stored.
- Domain only knows contracts and business meaning.
- Domain should be максимально stable and reusable.
- If something is a business concept, it belongs to Domain.
- If something defines what the app can do from business perspective, it belongs to Domain.
- Use protocols to describe capabilities.
- Use cases must express business actions clearly.

Examples:
- FetchUserProfileUseCase
- SearchByPhotoUseCase
- RestorePurchaseUseCase
- SaveHistoryItemUseCase
- BillingRepository
- SearchRepository
- AuthRepository

### Data layer

Purpose:
- implement Domain contracts
- orchestrate data flow between Domain and lower-level systems
- map external/raw models into domain models
- combine remote/local/cache sources when needed

Data contains:
- Repository implementations
- Data source abstractions if needed
- DTO -> Domain mapping
- response/request mapping
- cache orchestration
- local + remote merge logic
- pagination orchestration
- retry/fallback orchestration when this is data-related

Data must NOT contain:
- UI logic
- SwiftUI / UIKit
- View state logic
- screen-specific formatting
- SDK config constants scattered randomly
- DI registration
- unrelated app bootstrapping

Rules:
- Data implements Domain protocols.
- Data depends on Domain abstractions and Infrastructure implementations.
- Repository implementation is the main bridge between business rules and technical data sources.
- Data may use remote sources, local sources, cache sources, token stores, etc.
- Data is allowed to know transport and storage details.
- Data is responsible for converting raw/technical data into Domain-friendly models.
- Data should not leak DTOs, response models, or SDK types into Domain or Presentation.
- If backend response shape changes, ideally the impact stays inside Data/Infrastructure, not in Domain/Presentation.

Examples:
- SearchRepositoryImpl
- BillingRepositoryImpl
- AuthRepositoryImpl
- ProfileRepositoryImpl
- HistoryRepositoryImpl

### Infrastructure layer

Purpose:
- technical implementations
- low-level services
- API clients
- network clients
- persistence adapters
- keychain/user defaults/file storage adapters
- third-party SDK wrappers
- configuration
- environment-specific details

Infrastructure contains:
- API clients
- network services
- request builders
- endpoints
- storage services
- token storage
- keychain wrappers
- user defaults wrappers
- file storage services
- SDK wrappers
- analytics adapters
- payment SDK clients
- backend service implementations
- app configuration
- environment configuration
- low-level cache engines

Infrastructure must NOT contain:
- ViewModels
- Views
- business use case logic
- screen-specific presentation logic
- business decisions that belong to Domain

Rules:
- Infrastructure is where technical details live.
- If code is tied to URLSession, Alamofire, Keychain, UserDefaults, Adapty, Firebase, analytics SDKs, backend transport, file system, or any external framework, it most likely belongs to Infrastructure.
- Infrastructure should expose clean interfaces for upper layers.
- Wrap third-party SDKs behind protocols/adapters when reasonable.
- Do not spread SDK calls throughout the app.
- Keep framework-specific code isolated.

Examples:
- NetworkClient
- URLSessionNetworkClient
- APIRequestBuilder
- AuthAPIService
- SearchAPIService
- KeychainTokenStore
- UserDefaultsBillingStateStore
- AdaptyClient
- FirebaseAnalyticsTracker
- RemoteConfigProvider

### Application layer

Purpose:
- composition root
- dependency graph assembly
- DI registrations
- app startup wiring
- feature assembly
- bootstrapping

Application contains:
- App entry point
- App assembler
- ServicesAssembly
- scene assembly registration
- DI container setup
- startup coordinators if used as app composition

Application must NOT contain:
- business logic
- repository implementation details mixed with UI
- screen layout code
- transport parsing logic

Rules:
- Swinject is the only DI mechanism in this project.
- All services, repositories, use cases, and ViewModels must be registered through the Application layer.
- Do not manually create complex dependency chains inside Views or random files.
- Do not bypass DI if dependency can be resolved properly through container.
- Main registration point: `Application/ServicesAssembly.swift`

### Core layer

Purpose:
- shared reusable cross-feature utilities
- design system
- tokens
- common helpers
- extensions that are truly global
- reusable UI primitives
- cross-project utilities that do not belong to a specific feature

Core contains:
- Tokens
- scaling utilities
- reusable UI components
- generic helpers
- global lightweight utilities

Core must NOT contain:
- feature-specific business logic
- repository implementations
- backend-specific flows

---

## Strict dependency direction

Dependency direction must remain clean:

Presentation -> Domain
Application -> Presentation/Domain/Data/Infrastructure (for composition only)
Data -> Domain, Infrastructure
Infrastructure -> no dependency on Presentation or business UI rules
Domain -> depends on nothing UI/framework-specific

Important:
- Domain must not depend on Data.
- Domain must not depend on Infrastructure.
- Presentation must not depend directly on Infrastructure for business operations.
- Views must not talk directly to repositories/services.
- Views and ViewModels must not call API clients directly.

---

## Protocol-Oriented Programming rules

We use Protocol-Oriented Programming by default.

Rules:
1. Depend on protocols, not on concrete classes.
2. Every important service boundary should be described by a protocol.
3. Repositories must be accessed through protocols defined in Domain.
4. Use cases must be injected as protocols where appropriate.
5. SDK wrappers should be hidden behind protocols when possible.
6. Storage mechanisms should be hidden behind protocols.
7. Avoid hard-coding concrete dependencies deep inside business flow.
8. Prefer constructor injection.

Examples:
- `BillingRepository` protocol in Domain
- `BillingRepositoryImpl` in Data
- `NetworkClientProtocol` in Infrastructure
- `TokenStoreProtocol` in Infrastructure
- `FetchProfileUseCaseProtocol` in Domain

---

## SOLID rules

We follow SOLID 100%.

### Single Responsibility Principle
- Every type should have one reason to change.
- If a file/class/view model/service grows too much, split it.
- Do not create giant files with mixed concerns.
- Separate networking, mapping, caching, persistence, and business orchestration when it makes sense.

### Open/Closed Principle
- Extend behavior through new implementations, adapters, strategies, or mappers.
- Avoid changing stable business rules when adding new integrations.

### Liskov Substitution Principle
- Protocol-based abstractions must remain interchangeable.
- Alternative implementations must preserve expected behavior.

### Interface Segregation Principle
- Prefer small focused protocols over large “do everything” protocols.
- Do not create fat service interfaces.

### Dependency Inversion Principle
- High-level modules depend on abstractions.
- Domain defines abstractions for business-facing dependencies.
- Data/Infrastructure implement them.

---

## MVVM rules

We follow MVVM 100%.

Rules:
- View = rendering + forwarding actions
- ViewModel = presentation state + interaction orchestration through use cases
- Model = domain/business models or scene-local UI models where appropriate

View must NOT:
- call backend
- instantiate services
- perform business decisions
- contain persistence logic
- parse API responses
- own app-wide dependencies

ViewModel must:
- receive dependencies via init
- depend on protocols
- expose UI state clearly
- transform use case output into presentation-ready state
- remain testable

ViewModel must NOT:
- contain raw networking code
- construct repository implementations
- directly use third-party SDK details unless this is purely presentation glue and there is no better boundary
- become a god object

---

## Rules for services

When adding any service, always determine first:
1. Is it business-facing or technical?
2. Is it defining a capability or implementing it?
3. Is it low-level infrastructure or domain-level abstraction?
4. Does it belong to Domain, Data, or Infrastructure?

### Domain service
Put it in Domain if:
- it represents business capability
- it expresses business rules
- it is framework-agnostic
- it is part of use case execution rules

Examples:
- eligibility calculation
- subscription business rules
- result ranking business rules
- domain validation rules

### Data service / repository implementation
Put it in Data if:
- it implements a domain repository/service contract
- it orchestrates fetching/saving from multiple sources
- it maps DTOs into domain models
- it decides remote/local/cache flow

Examples:
- repository implementation
- remote+cache merge logic
- transport-to-domain mapper coordination

### Infrastructure service
Put it in Infrastructure if:
- it talks to backend
- it performs network requests
- it wraps SDKs
- it reads/writes Keychain/UserDefaults/files
- it sends analytics/crash logs/push registration
- it works with tokens, headers, sessions, endpoints, serializers

Examples:
- API service
- network client
- token storage
- secure storage
- analytics tracker
- purchase SDK wrapper
- remote config client

---

## Network and backend rules

All backend-related logic must be placed correctly across Domain / Data / Infrastructure.

### Domain for backend-related features
Domain should contain:
- business entities returned/used by feature
- repository protocols
- use cases
- business validation
- business errors if needed

Domain must not know:
- endpoint paths
- HTTP methods
- request bodies
- DTO models
- headers
- networking library
- auth token storage details

### Data for backend-related features
Data should contain:
- repository implementation
- DTO -> Domain mapping
- Domain -> request model mapping if needed
- orchestration of remote/local/cache
- pagination coordination
- business-safe error translation when needed

### Infrastructure for backend-related features
Infrastructure should contain:
- endpoint definitions
- request builders
- API services
- URLSession/Alamofire clients
- interceptors
- auth header injection
- serializer/decoder setup
- raw request/response models if separated here
- token store implementations
- retry policies if low-level
- multipart builders
- network transport details

Rules:
- Presentation never calls backend directly.
- ViewModel never builds requests directly.
- Domain never knows transport details.
- Data shields the app from raw backend contracts.
- Infrastructure shields the app from low-level implementation details.

---

## Rules for caching and persistence

If something is cache/persistence related, place it in the proper technical layer.

### Domain
Domain may define cache-related business need through abstraction if necessary:
- repository contract
- storage-facing abstraction only if it is business-relevant

Domain must not know:
- UserDefaults
- Keychain
- file paths
- CoreData/Realm specifics
- JSON file storage implementation

### Data
Data decides:
- when to read from cache
- when to refresh from remote
- when to fallback to local
- how to merge cache + remote for repository output

### Infrastructure
Infrastructure implements:
- Keychain storage
- UserDefaults storage
- disk cache
- database adapter
- raw persistence clients

Rules:
- low-level cache engine belongs to Infrastructure
- cache orchestration belongs to Data
- business meaning of cached entities belongs to Domain

---

## Rules for third-party SDK integration

Any external SDK must be isolated as much as reasonably possible.

Examples:
- Adapty
- Firebase
- AppsFlyer
- analytics SDKs
- crash reporting SDKs
- auth SDKs

Rules:
1. Do not spread SDK calls across Presentation.
2. Do not let SDK models leak into Domain.
3. Wrap SDK-specific behavior in Infrastructure adapters/clients.
4. Expose clean interfaces upward.
5. Map SDK objects to internal models before leaving Infrastructure/Data.

---

## File and folder structure rules

We prefer many small logical files over giant mixed files.

Rules:
1. Each scene has its own folder in `Presentation`.
2. Minimum scene structure:
   - `<SceneName>View.swift`
   - `<SceneName>ViewModel.swift`
3. Additional scene parts should be split into logical files:
   - Components
   - Models
   - Router
   - State
   - Mapper
4. Do not keep multiple major scenes in one file.
5. If a file becomes too large, split it.
6. If logic deserves its own type, create a new file.
7. File names must be explicit and intention-revealing.
8. Folder placement must reflect architectural responsibility.

---

## DI rules

DI is done only via Swinject.

Rules:
1. Register all services, repositories, use cases, and ViewModels in `Application/ServicesAssembly.swift`.
2. Do not manually instantiate dependencies in View.
3. Do not hide broken DI with hacks in UI.
4. Constructor injection is preferred.
5. Resolve protocols, not concrete implementations, when appropriate.
6. If a new dependency is introduced, register it properly in DI.
7. Keep composition root centralized.

---

## UI rules

These rules are mandatory:
1. All sizes, paddings, spacings, radii, offsets, frame values, and screenshot-based dimensions must use `.scale`.
2. Fonts must be taken from `Tokens`.
3. Colors must be taken from `Tokens` (or token-backed assets when applicable).
4. Do not use random system fonts/colors instead of project tokens.
5. UI must remain consistent with design system.

---

## Assets rules

When asked to create assets:
1. Place them logically inside `Assets.xcassets`.
2. Group them in appropriate folders.
3. If the proper folder does not exist, create it.
4. Do not create messy ungrouped assets.
5. Asset structure must remain organized and intention-revealing.
6. Created asset placeholders can remain empty if the user will insert the final image manually.

---

## What to do before writing code

Before implementing, always think:
1. Which layer does this belong to?
2. Is this a business rule or a technical implementation?
3. Should this be a protocol?
4. Should this be split into separate files?
5. Will this break Clean Architecture or MVVM?
6. Am I leaking SDK/network/persistence details upward?
7. Can this dependency be injected properly via Swinject?
8. Is this code placed in the most logical folder?

If the answer suggests separation, create additional files and place them properly.

---

## Output rules for generated code

When modifying code:
1. Preserve architecture.
2. Preserve layer boundaries.
3. Do not take shortcuts that violate Clean Architecture, MVVM, or SOLID.
4. Create new files when necessary.
5. Keep code logically distributed across folders.
6. Prefer protocol-based design.
7. Keep implementations testable and maintainable.
8. Do not produce giant monolithic files when decomposition is more correct.
9. Respect existing project structure and naming style.

If a task can be solved either by putting everything into one file or by creating proper types/files/layers, always choose the proper layered solution.

## Project-specific mandatory rules

This project has additional mandatory rules:

1. All dimensions must use `.scale`.
   This includes:
   - spacing
   - padding
   - width
   - height
   - corner radius
   - offsets
   - screenshot-based measured sizes

2. Fonts must always come from `Tokens`.
3. Colors must always come from `Tokens`.
4. We do not use random `.system(...)` fonts in UI unless the project explicitly already allows that in a specific shared token wrapper.
5. We strictly keep scenes separated by folders inside `Presentation`.
6. Every scene must have separate files at minimum:
   - `<SceneName>View.swift`
   - `<SceneName>ViewModel.swift`
7. If logic grows, split it into additional files instead of creating giant files.
8. Backend-related code must be placed properly across Domain / Data / Infrastructure.
9. Cache-related implementation must live in the proper layer, not mixed into UI or random services.
10. Do not create dependencies manually inside Views if they can be injected.
11. Use Swinject only through `Application/ServicesAssembly.swift`.
12. If creating a new file or folder is the cleaner architectural choice, do it.
13. Prefer clean folder organization over quick inline implementation.
