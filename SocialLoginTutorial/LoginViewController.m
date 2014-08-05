//
//  ViewController.m
//  SocialLoginTutorial
//
//  Created by Carlo Vigiani on 2/Aug/14.
//  Copyright (c) 2014 Viggiosoft. All rights reserved.
//

#import "LoginViewController.h"
#import "LoginService.h"

@interface LoginViewController ()

@property (weak, nonatomic) IBOutlet UIButton *facebookButton;
@property (weak, nonatomic) IBOutlet UIButton *twitterButton;
@property (weak, nonatomic) IBOutlet UISegmentedControl *facebookBugSwitch;

@end

@implementation LoginViewController
            
#pragma mark - Init

- (void)viewDidLoad {

    [[LoginService service] setFacebookAppId:@"1452610158359317"];
    [[LoginService service] setFacebookBug:(self.facebookBugSwitch.selectedSegmentIndex==0)];
    [[LoginService service] setSaveAccountInfoInUserDefaults:YES];

}

- (void)viewDidAppear:(BOOL)animated {
    
    if([[LoginService service] isLoggedIn]) {
        
        [self performSegueWithIdentifier:@"LoggedIn" sender:nil];
    } 
}


#pragma mark - IBAction

- (IBAction)facebook:(id)sender {
    [[LoginService service] loginWithService:LoginServiceTypeFacebook completion:^(LoginServiceAnswer answer, NSError *error) {
        [self followupAnswer:answer error:error];
    }];}

- (IBAction)twitter:(id)sender {
    [[LoginService service] loginWithService:LoginServiceTypeTwitter completion:^(LoginServiceAnswer answer, NSError *error) {
        [self followupAnswer:answer error:error];
    }];
}

- (void)followupAnswer:(LoginServiceAnswer)answer error:(NSError *)error {
    switch (answer) {
        case LoginServiceAnswerAccessNotGranted:
            [self showErrorWithMessage:@"You didn't grant access to the service. Go to your privacy settings to enable access to this app again." error:error];
            break;
        case LoginServiceAnswerNoAccounts:
            [self showErrorWithMessage:@"There are no accounts set for this service. Go to your device settings to create a new account. Other implementations can go through web-based SSO access." error:error];
            break;
        case LoginServiceAnswerMultipleAccounts:
            [self selectOneAccount:[[LoginService service] multipleAccounts]];
            break;
        case LoginServiceAnswerValid:
            [self performSegueWithIdentifier:@"LoggedIn" sender:nil];
            break;
        default:
            [self showErrorWithMessage:@"Error in the login procedure." error:error];
            break;
    }
}

#pragma mark - User interaction

- (void)showErrorWithMessage:(NSString *)message error:(NSError *)error {
    
    
    // builds alert explanation message
    NSMutableString *explanationMessage = [NSMutableString new];
    if(message) {
        [explanationMessage appendString:message];
    }
    if(error) {
        if(explanationMessage.length>0) {
            [explanationMessage appendString:@"\n"];
        }
        [explanationMessage appendString:error.localizedDescription];
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error"
                                                                              message:explanationMessage
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"Close"
                                                          style:UIAlertActionStyleDefault
                                                        handler:NULL];
    
    [alertController addAction:closeAction];
    [self presentViewController:alertController animated:YES completion:NULL];
}

- (void)selectOneAccount:(NSArray *)accounts {
    
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"Mutliple accounts"
                                                                         message:@"Select the account you want to login with"
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                    style:UIAlertActionStyleCancel
                                                  handler:NULL]];
    for(NSString *accountIdentifier in accounts) {
        [actionSheet addAction:[UIAlertAction actionWithTitle:accountIdentifier
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
                                                          [[LoginService service] twitterLoginWithUsername:accountIdentifier  completion:^(LoginServiceAnswer answer, NSError *error) {
                                                              [self followupAnswer:answer error:error];
                                                          }];
                                                      }]];
    }
    [self presentViewController:actionSheet animated:YES completion:NULL];
}


@end
