//
//  PostViewController.m
//  SocialLoginTutorial
//
//  Created by Carlo Vigiani on 2/Aug/14.
//  Copyright (c) 2014 Viggiosoft. All rights reserved.
//

#import "PostViewController.h"
#import "LoginService.h"

@import Social;

@interface PostViewController ()
- (IBAction)post:(id)sender;
@property (weak, nonatomic) IBOutlet UIImageView *userImage;
@property (weak, nonatomic) IBOutlet UILabel *userName;
- (IBAction)logout:(id)sender;

@end

@implementation PostViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    
    ACAccount *currentAccount = [[LoginService service] currentAccount];
    
    // user name label
    self.userName.text = [@"@" stringByAppendingString:currentAccount.username];
    
    // load profile image
    ACAccountType *currentAccountType = [currentAccount accountType];
    if([currentAccountType.identifier isEqualToString:ACAccountTypeIdentifierFacebook]) {
        [self downloadFacebookProfileImageForAccount:currentAccount];
    } else if([currentAccountType.identifier isEqualToString:ACAccountTypeIdentifierTwitter]) {
        [self downloadTwitterProfileImageForAccount:currentAccount];
    }
    
}

- (void)appDidBecomeActive:(NSNotification *)notification {
    
    if(![[LoginService service] isLoggedIn]) {
        [self logout:nil];
    }
}

#pragma mark - Profile image

- (void)downloadFacebookProfileImageForAccount:(ACAccount *)account {
    
    NSURL *imageURL = [NSURL URLWithString:@"https://graph.facebook.com/v2.0/me/picture/"];
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook
                                             requestMethod:SLRequestMethodGET
                                                       URL:imageURL
                                                parameters:nil];
    request.account = account;
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if(error) {
            [self showPostError:error];
            return;
        }
        if(responseData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *image = [UIImage imageWithData:responseData];
                self.userImage.image = image;
            });
        }
    } ];
}

- (void)downloadTwitterProfileImageForAccount:(ACAccount *)account {
    
    NSURL *userProfileURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.twitter.com/1.1/users/show.json?screen_name=%@",account.username]];
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                            requestMethod:SLRequestMethodGET
                                                      URL:userProfileURL
                                               parameters:nil];
    request.account = account;
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if(error) {
            [self showPostError:error];
            return;
        }
        NSDictionary *userInfo = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:NULL];
        NSURL *imageURL = [NSURL URLWithString:userInfo[@"profile_image_url_https"]];
        if(imageURL) {
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *image = [UIImage imageWithData:imageData];
                self.userImage.image = image;
            });
        }
    }];
    
}

#pragma mark - Post

- (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *_dateFormatter;
    if(!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.timeStyle = NSDateFormatterMediumStyle;
        _dateFormatter.dateStyle = NSDateFormatterNoStyle;
    }
    return _dateFormatter;
}

- (NSString *)postString {
    return [NSString stringWithFormat:@"It's %@ now.",[[self dateFormatter] stringFromDate:[NSDate date]]];
}

- (void)sendFacebookPostForAccount:(ACAccount *)account {
    
    // for Facebook we need to ask extra permission (post)
    [[[LoginService service] accountStore] requestAccessToAccountsWithType:account.accountType
                                                                   options:@{
                                                                             ACFacebookAppIdKey:[[LoginService service] facebookAppId],
                                                                             ACFacebookAudienceKey:ACFacebookAudienceFriends,
                                                                             ACFacebookPermissionsKey:@[@"publish_actions"]
                                                                             }
                                                                completion:^(BOOL granted, NSError *error) {
                                                                    if(!granted) {
                                                                        [self showPostError:error];
                                                                    } else {
                                                                        SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook
                                                                                                                requestMethod:SLRequestMethodPOST
                                                                                                                          URL:[NSURL URLWithString:@"https://graph.facebook.com/v2.0/me/feed"]
                                                                                                                   parameters:@{
                                                                                                                                @"message":[self postString]}];
                                                                        request.account=account;
                                                                        [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                                                                            if(error) {
                                                                                [self showPostError:error];
                                                                            } else {
                                                                                NSError *jsonError = nil;
                                                                                NSDictionary *answerDictionary = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonError];
                                                                                if(jsonError) {
                                                                                    [self showPostError:jsonError];
                                                                                } else {
                                                                                    if(answerDictionary[@"error"]) {
                                                                                        NSDictionary *error = answerDictionary[@"error"];
                                                                                        [self showPostError:[NSError errorWithDomain:@"SocialLoginTutorial" code:100 userInfo:@{NSLocalizedDescriptionKey:error[@"message"]}]];

                                                                                    } else {
                                                                                        [self showPostSuccess:[self postString]];
                                                                                    }
                                                                                   
                                                                                }
                                                                            }
                                                                            
                                                                        }];
                                                                    }
                                                                }];
    
    
}

- (void)sendTwitterPostForAccount:(ACAccount *)account {
    
    NSString *postString = [self postString];
    NSDictionary *postParams = @{
                                 @"status":postString
                                 };
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                            requestMethod:SLRequestMethodPOST
                                                      URL:[NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update.json"]
                                               parameters:postParams];
    request.account = account;
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if(error) {
            [self showPostError:error];
        } else {
            NSError *error = nil;
            NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
            if(!jsonDict) {
                [self showPostError:error];
            } else {
                if(jsonDict[@"errors"]) {
                    NSDictionary *error = [(NSArray *)jsonDict[@"errors"] firstObject];
                    [self showPostError:[NSError errorWithDomain:@"SocialLoginTutorial" code:100 userInfo:@{NSLocalizedDescriptionKey:error[@"message"]}]];
                } else {
                    [self showPostSuccess:postString];
                }
            }
        }
    }];
    
}

- (void)showPostError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Post error"
                                                                                 message:error.localizedDescription
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:NULL]];
        [self presentViewController:alertController animated:YES completion:NULL];
    });
}

- (void)showPostSuccess:(NSString *)postString {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Check your feed!"
                                                                                 message:[NSString stringWithFormat:@"We just sent this nice post for you:\n'%@'",postString]
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:NULL]];
        [self presentViewController:alertController animated:YES completion:NULL];
    });
}


#pragma mark - IBAction

- (IBAction)post:(id)sender {

    // load profile image
    ACAccount *currentAccount = [[LoginService service] currentAccount];
    ACAccountType *currentAccountType = [currentAccount accountType];
    if([currentAccountType.identifier isEqualToString:ACAccountTypeIdentifierFacebook]) {
        [self sendFacebookPostForAccount:currentAccount];
    } else if([currentAccountType.identifier isEqualToString:ACAccountTypeIdentifierTwitter]) {
        [self sendTwitterPostForAccount:currentAccount];
    }

}

- (IBAction)logout:(id)sender {
    
    [[LoginService service] logout];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}
@end
