//
//  LoginService.h
//  SocialLoginTutorial
//
//  Created by Carlo Vigiani on 2/Aug/14.
//  Copyright (c) 2014 Viggiosoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@import Accounts;


typedef NS_ENUM(NSInteger, LoginServiceType) {
    LoginServiceTypeTwitter = 0,
    LoginServiceTypeFacebook = 1
};

typedef NS_ENUM(NSInteger, LoginServiceAnswer) {
    LoginServiceAnswerUndefined = -1,
    LoginServiceAnswerAccessNotGranted = 0,
    LoginServiceAnswerNoAccounts = 1,
    LoginServiceAnswerInvalidAccount = 2,
    LoginServiceAnswerValid = 3,
    LoginServiceAnswerOtherError = 4,
    LoginServiceAnswerMultipleAccounts = 5,

};

typedef void(^LoginServiceAnswerBlock)(LoginServiceAnswer answer,NSError *error);

@interface LoginService : NSObject

@property (copy,nonatomic) NSString *facebookAppId;
@property (strong,readonly) NSArray *multipleAccounts;
@property (assign,nonatomic) BOOL facebookBug;
@property (assign,nonatomic) BOOL saveAccountInfoInUserDefaults;
@property (strong,readonly) ACAccount *currentAccount;
@property (readonly) ACAccountStore *accountStore;

+ (instancetype)service;

- (void)loginWithService:(LoginServiceType)serviceType completion:(LoginServiceAnswerBlock)completionBlock;
- (void)twitterLoginWithUsername:(NSString *)username completion:(LoginServiceAnswerBlock)completionBlock;
- (BOOL)isLoggedIn;
- (void)logout;

@end
