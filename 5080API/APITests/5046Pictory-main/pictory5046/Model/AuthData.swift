import Foundation

struct AuthResponse: Decodable {
    let error: Bool
    let code: String?
    let message: String?
    let data: AuthData?
}

struct AuthData: Decodable {
    let id: Int
    let userId: String
    let referralCode: String
    let availableBonuses: Int
    let startAt: String?
    let endAt: String?
    let activePlanId: Int?
    let planTokens: Int?
    let isActivePlan: Bool
    let isActiveSubscription: Bool
    let isHasWebSubscription: Bool
    let isWebPayment: Bool
    let isOnboardingCompleted: Bool?
    let planInfo: String?
    let payments: [String]
    let gender: String
    let source: String
    let availableGenerations: Int
    let isNewRegistered: Bool
    let profile: AuthProfile
    let stat: AuthStat
    let avatars: [String]

    enum CodingKeys: String, CodingKey {
        case id, userId, referralCode, availableBonuses, startAt, endAt
        case activePlanId, planTokens, isActivePlan, isActiveSubscription
        case isHasWebSubscription
        case isWebPayment = "IsWebPayment"
        case isOnboardingCompleted, planInfo, payments, gender, source
        case availableGenerations, isNewRegistered, profile, stat, avatars
    }
}

struct AuthProfile: Decodable {
    let photo: String?
    let displayName: String?
    let twitter: String?
    let instagram: String?
    let login: String?
    let userId: String
}

struct AuthStat: Decodable {
    let id: Int
    let name: String?
    let login: String?
    let gender: String
    let isGodModeEnabled: Bool
    let startAt: String?
    let maxPhotos: Int
    let maxStyles: Int
    let maxModels: Int
    let isActiveTariff: Bool
    let tariffId: Int?
    let isUnsubscribed: Bool
    let isFreeTariff: Bool
    let maxFreeGenerations: Int
    let freeGenerationsUsed: Int
    let maxUploadPhotos: Int
    let minUploadPhotos: Int
    let totalGenerations: Int
    let totalGenerationsTemplate: Int
    let totalGenerationsGod: Int
    let totalModels: Int
    let availableModels: Int
    let availableGenerations: Int
    let totalTrialGenerations: Int
    let sumExtraPayments: Int
    let bonusPercent: Int
    let createdAt: String
}

// MARK: - Profile

struct ProfileResponse: Decodable {
    let error: Bool
    let code: String?
    let message: String?
    let data: ProfileData?
}

struct ProfileData: Decodable {
    let id: Int
    let userId: String
    let referralCode: String
    let availableBonuses: Int
    let startAt: String?
    let endAt: String?
    let activePlanId: Int?
    let planTokens: Int?
    let isActivePlan: Bool
    let isActiveSubscription: Bool
    let isHasWebSubscription: Bool
    let isWebPayment: Bool
    let isOnboardingCompleted: Bool?
    let planInfo: PlanInfo?
    let payments: [String]
    let gender: String
    let source: String
    let availableGenerations: Int
    let isNewRegistered: Bool
    let profile: AuthProfile
    let stat: AuthStat
    let avatars: [String]

    enum CodingKeys: String, CodingKey {
        case id, userId, referralCode, availableBonuses, startAt, endAt
        case activePlanId, planTokens, isActivePlan, isActiveSubscription
        case isHasWebSubscription
        case isWebPayment = "IsWebPayment"
        case isOnboardingCompleted, planInfo, payments, gender, source
        case availableGenerations, isNewRegistered, profile, stat, avatars
    }
}

struct PlanInfo: Decodable {
    let id: Int
    let code: String
    let title: String
    let productId: String?
    let maxPhotos: Int
    let maxAvatars: Int
    let price: Double
    let oldPrice: Double?
    let isForSubscription: Bool
    let isForOption: Bool
    let isForAvatar: Bool
}
