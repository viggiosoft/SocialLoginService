//
//  LoginService.m
//  SocialLoginTutorial
//
//  Created by Carlo Vigiani on 2/Aug/14.
//  Copyright (c) 2014 Viggiosoft. All rights reserved.
//

#import "LoginService.h"

static NSString *kLoginServiceDefaultsKey = @"LoginService";
static NSString *kLoginServiceAccountType = @"AccountType";
static NSString *kLoginServiceAccountUserIdentifier = @"AccountUserIdentifier";

static NSString *kLoginServiceErrorDomain = @"LoginService";

@interface LoginService () {
    ACAccount *_currentAccount;
    ACAccountStore *_accountStore;
}

@property (strong,nonatomic) NSArray *multipleAccounts;

@end

@implementation LoginService

#pragma mark - Init

+ (instancetype)service {
    static LoginService *_sharedInstance;
    static dispatch_once_t onceToken;
dispatch_once(&onceToken, ^{
    _sharedInstance = [[LoginService alloc] init];
});
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(accountStoreDidChange:)
                                                     name:ACAccountStoreDidChangeNotification
                                                   object:nil];
        self.saveAccountInfoInUserDefaults = YES;
    }
    return self;
}

#pragma mark - Notification

- (void)accountStoreDidChange:(NSNotification *)notification {
    
}

#pragma mark - Lazy getters

- (ACAccountStore *)accountStore {
    if(!_accountStore) {
        _accountStore = [[ACAccountStore alloc] init];
    }
    return _accountStore;
}

- (ACAccountType *)accountTypeForService:(LoginServiceType)service {
    
    switch (service) {
        case LoginServiceTypeFacebook:
            return [[self accountStore] accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
            break;
        case LoginServiceTypeTwitter:
            return [[self accountStore] accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
            break;
        default:
            return nil;
            break;
    }
}

#pragma mark - Setters

- (void)setCurrentAccount:(ACAccount *)currentAccount {
    _currentAccount = currentAccount;
    [self saveAccountInfo:_currentAccount];
}

- (ACAccount *)currentAccount {
    return _currentAccount;
}

#pragma mark - Login

- (BOOL)isLoggedIn {
    
    // get saved info
    ACAccountType *savedAccountType = [self savedAccountType];
    if(!savedAccountType) {
        return NO;
    }
    NSString *savedUsername = [self savedUsername];
    if(!savedUsername) {
        return NO;
    }
    
    // check permission
    if(![savedAccountType accessGranted]) {
        return NO;
    }
    
    // check account
    NSArray *accounts = [[self accountStore] accountsWithAccountType:savedAccountType];
    for(ACAccount *_account in accounts) {
        if([_account.username isEqualToString:savedUsername]) {
            self.currentAccount = _account;
            return YES;
        }
    }
    return NO;
    
}

- (void)loginWithService:(LoginServiceType)serviceType completion:(LoginServiceAnswerBlock)completionBlock {
    
    ACAccountType *accountType = [self accountTypeForService:serviceType];
    
    // check service type
    if(!accountType) {
        NSError *error = [NSError errorWithDomain:kLoginServiceErrorDomain
                                             code:100
                                         userInfo:@{NSLocalizedDescriptionKey:@""}
                          ];
        
        completionBlock(LoginServiceAnswerOtherError,error);
        return;
    }
    
    // create granted block
    void(^grantedBlock)() = ^() {
        NSArray *accounts = [self.accountStore accountsWithAccountType:accountType];
        if(accounts.count==0) {
            completionBlock(LoginServiceAnswerNoAccounts,nil);
        } else if(accounts.count==1) {
            self.currentAccount = accounts.lastObject;
            completionBlock(LoginServiceAnswerValid,nil);
        } else {
            NSMutableArray *tmpAccounts = [NSMutableArray new];
            for(ACAccount *account in accounts) {
                [tmpAccounts addObject:account.username];
            }
            self.multipleAccounts = [NSArray arrayWithArray:tmpAccounts];
            completionBlock(LoginServiceAnswerMultipleAccounts,nil);
        }
    
    };
    
    
    
    // ask for permission
    if(!accountType.accessGranted) {
        
        NSDictionary *options = nil;
        
        if([[accountType identifier] isEqualToString:ACAccountTypeIdentifierFacebook]) {
            NSArray *permissions = self.facebookBug?@[@"email",@"public_profile",@"user_friends"]:@[@"email"];
            options = @{
                        ACFacebookAppIdKey:self.facebookAppId,
                        ACFacebookPermissionsKey:permissions,
                        ACFacebookAudienceKey:ACFacebookAudienceFriends
                        };
        }
        
        [[self accountStore] requestAccessToAccountsWithType:accountType
                                                     options:options
                                                  completion:^(BOOL granted, NSError *error) {
                                                      
                                                      if(granted) {
                                                          
                                                          dispatch_async(dispatch_get_main_queue(),^{
                                                              grantedBlock();
                                                          });
                                                          
                                                       } else {
                                                           LoginServiceAnswer answerCode;
                                                           
                                                           if(error.code==ACErrorAccountNotFound) {
                                                               answerCode = LoginServiceAnswerNoAccounts; // this is the answer returned when there are no Facebook accounts configured
                                                           } else {
                                                               answerCode = LoginServiceAnswerAccessNotGranted;
                                                           }
                                                           
                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                               completionBlock(answerCode,error);
                                                           });
                                                           
                                                      }
                                                  }];

    } else {
        
        dispatch_async(dispatch_get_main_queue(),^{
            grantedBlock();
        });
    }
    
}

- (void)twitterLoginWithUsername:(NSString *)username completion:(LoginServiceAnswerBlock)completionBlock {
    
    ACAccountType *accountType = [self accountTypeForService:LoginServiceTypeTwitter];
    if(![accountType accessGranted]) {
        completionBlock(LoginServiceAnswerAccessNotGranted,nil);
        return;
    }
    
    NSArray *accounts = [[self accountStore] accountsWithAccountType:accountType];
    if(accounts.count==0) {
        completionBlock(LoginServiceAnswerNoAccounts,nil);
        return;
    }
    
    for(ACAccount *_account in accounts) {
        if([username isEqualToString:[_account username]]) {
            completionBlock(LoginServiceAnswerValid,nil);
            self.currentAccount = accounts.lastObject;
            return;
        }
    }
    completionBlock(LoginServiceAnswerInvalidAccount,nil);
}

#pragma mark - Logout

- (void)logout {
    
    self.currentAccount = nil;

}

#pragma mark - User defaults

- (NSURL *)savedInfoURL {

    NSURL *documentURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *accountURL = [documentURL URLByAppendingPathComponent:@"login.plist"];
    return accountURL;
}

- (void)saveAccountInfo:(ACAccount *)account {
    
    if(!account) {
        // logout: delete saved info
        
        if(self.saveAccountInfoInUserDefaults) {
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults removeObjectForKey:kLoginServiceDefaultsKey];
        } else {
            
            [[NSFileManager defaultManager] removeItemAtURL:[self savedInfoURL] error:NULL];
        }

    } else {
        
        NSDictionary *infoDictionary;
        
        if(self.saveAccountInfoInUserDefaults) {
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSDictionary *infoDictionary = @{
                                             kLoginServiceAccountType:account.accountType.identifier,
                                             kLoginServiceAccountUserIdentifier:account.username
                                             };
            [defaults setObject:infoDictionary forKey:kLoginServiceDefaultsKey];
            [defaults synchronize];
        } else {
            
            // save also to private file
            [infoDictionary writeToURL:[self savedInfoURL] atomically:YES];
        }
   }
    
    
}

- (NSString *)savedUsername {

    if(self.saveAccountInfoInUserDefaults) {
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *infoDictionary = [defaults dictionaryForKey:kLoginServiceDefaultsKey];
        return infoDictionary[kLoginServiceAccountUserIdentifier];
    } else {
        
        NSDictionary *infoDictionary = [NSDictionary dictionaryWithContentsOfURL:[self savedInfoURL]];
        return infoDictionary[kLoginServiceAccountUserIdentifier];
    }
    
}

- (ACAccountType *)savedAccountType {
    
    NSDictionary *infoDictionary;
    NSString *accountTypeIdentifier;
    
    if(self.saveAccountInfoInUserDefaults) {
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        infoDictionary = [defaults dictionaryForKey:kLoginServiceDefaultsKey];
        accountTypeIdentifier = infoDictionary[kLoginServiceAccountType];
    } else {
        
        infoDictionary = [NSDictionary dictionaryWithContentsOfURL:[self savedInfoURL]];
        accountTypeIdentifier =  infoDictionary[kLoginServiceAccountType];
    }
    
    return [[self accountStore] accountTypeWithAccountTypeIdentifier:accountTypeIdentifier];
 }


@end
