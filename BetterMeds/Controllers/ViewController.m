//
//  ViewController.m
//  BetterMeds
//
//  Created by Vinay Jain on 5/11/15.
//  Copyright (c) 2015 Vinay Jain. All rights reserved.


#import "ViewController.h"
#import "MedicineDetailsController.h"
#import "NetworkManager.h"

@interface ViewController ()<UITextFieldDelegate,NetworkDelegate,UITableViewDataSource,UITableViewDelegate,UIAlertViewDelegate>{
    
    NSArray *medicineData;
    __weak IBOutlet UITableView *medicines;
    int tag;
}
@property int failedCount;
@property (weak, nonatomic) IBOutlet UITextField *searchField;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicator;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *centralIndicator;

@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *headers;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topSpace;

@end

@implementation ViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"ViewController"];
    }
    return self;
}
-(void)viewDidLoad{
    
    self.navigationController.navigationBar.titleTextAttributes = @{ NSForegroundColorAttributeName : [UIColor whiteColor] };
    self.title = @"Search";
    [NetworkManager sharedInstance].delegate = self;
    
    [self.searchField addTarget:self
                         action:@selector(textFieldTextDidChange:)
               forControlEvents:UIControlEventEditingChanged];
    
    
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.backBarButtonItem = backButton;
    
    medicines.hidden = true;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardHide) name:UIKeyboardDidHideNotification object:nil];
}

-(void)viewDidLayoutSubviews{
    
    CALayer *bottomBorder = [CALayer layer];
    bottomBorder.frame = CGRectMake(0, self.searchField.frame.size.height - 1, self.searchField.frame.size.width, 1);
    bottomBorder.backgroundColor = [UIColor darkGrayColor].CGColor;
    self.searchField.delegate = self;
    
    [self.searchField addTarget:self action:@selector(textFieldTextDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    [self.searchField.layer addSublayer:bottomBorder];
}

-(void)textFieldTextDidChange:(UITextField *)textField{
    
    if (textField.text.length > 2 ) {
        [self.indicator startAnimating];
        tag = 1;
        [[NetworkManager sharedInstance] getMedicineSuggestionsForID:textField.text];
    }
    else{
        [self.indicator stopAnimating];
    }
    self.failedCount = 0;
    
}

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    [UIView animateWithDuration:0.8 animations:^{
        [self.view layoutIfNeeded];
        self.topSpace.constant = 35;
        for (UILabel *label in self.headers) {
            label.alpha = 0;
        }
        [self.view layoutIfNeeded];
        
    }];
}



-(BOOL)textFieldShouldReturn:(UITextField *)textField{
    
    if ([textField.text isEqualToString:@""]) {
        medicineData = nil;
        [self.indicator stopAnimating];
        [medicines reloadData];
    }
    
    [textField resignFirstResponder];
    [UIView animateWithDuration:0.8 animations:^{
        [self.view layoutIfNeeded];
        self.topSpace.constant = 170;
        for (UILabel *label in self.headers) {
            label.alpha = 1;
        }
        [self.view layoutIfNeeded];
        
    }];
    
    return true;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    if ([medicineData count]) {
        return [medicineData count];
    }
    else{
        return 0;
    }
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:16];
    cell.textLabel.text = [[medicineData objectAtIndex:indexPath.row] valueForKey:@"suggestion"];
    
    return cell;
    
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    [self.centralIndicator startAnimating];
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[NetworkManager sharedInstance] getMedicineDetailsForID:[tableView cellForRowAtIndexPath:indexPath].textLabel.text];
    tag = 2;
}

-(void)onKeyboardHide{
    
    if ([self.searchField.text length] < 2) {
        medicines.hidden = true;
    }
    
}

-(void)updateDataSourceWith:(id)dataSource{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (tag == 1) {
            [self.indicator stopAnimating];
            medicineData = (NSArray*)dataSource;
            medicines.hidden = false;
            [medicines reloadData];
        }
        else if(tag == 2){
            [self.centralIndicator stopAnimating];
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            MedicineDetailsController *medicineDetailsController = [MedicineDetailsController new];
            medicineDetailsController.medicineDetails = (NSDictionary *)dataSource;
            if([dataSource[@"constituents"] count]){
                [self.navigationController pushViewController:medicineDetailsController animated:YES];
            }else{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"We cannot find data related to this medicine" preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    
                }];
                [alert addAction:okAction];
                [self presentViewController:alert animated:true completion:nil];
            }
        }
    });
    
}

-(void)requestFailedWithError:(int)errorCode{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.indicator stopAnimating];
        
        if (errorCode == NSURLErrorTimedOut) {
            if (self.failedCount < 1 && [self.searchField.text length] > 2) {
        
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Request Failed" message:@"Something went wrong, the app cannot connect to the web service" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
                [alert show];
                self.failedCount++;
            }
        }
    });
}
- (IBAction)goToTrueMD:(UIButton *)sender {
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http:www.truemd.in"]];
}

- (IBAction)goToFAQs:(UIButton *)sender {
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/vinayjn/TrueMD-iOS/blob/master/README.md"]];

}

@end
