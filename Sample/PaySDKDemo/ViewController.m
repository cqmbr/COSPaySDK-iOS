//
//  ViewController.m
//  PaySDKDemo
//
//  Created by zhanbin on 2018/5/7.
//  Copyright © 2018年 mbr. All rights reserved.
//

#import "ViewController.h"
#import <COSPaySDK/COSPaySDK.h>
//#import <DCPaySDK/DCPaySDK.h>
#import "DCPAPISigner.h"
#import <YYCategories.h>
#import <MBProgressHUD+BWMExtension/MBProgressHUD+BWMExtension.h>

static const NSString *urlPath = @"http://47.100.47.200:9927/payIndex/prepay";
static const NSString *channel = @"73088886094000";
static const NSString *merchantId = @"10000000000003";

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePayResult:) name:@"PayResult" object:nil];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)clickPayETHButton:(id)sender {
    
    [self prePay:@"34190899187000" amount:@"0.01"];
}
- (IBAction)clickPayPHButton:(id)sender {
    [self prePay:@"7739138616000" amount:@"1"];
}

- (IBAction)clickSimulationPayButton:(id)sender {
    [self doSimulationPay];
}

#pragma mark -
#pragma mark   ==============向服务端获取订单数据==============
-(void)prePay:(NSString *)coinId amount:(NSString *)amount{
    
    MBProgressHUD *hud = [MBProgressHUD bwm_showHUDAddedTo:self.view title:@"" animated:YES];
    NSString *urlString = [NSString stringWithFormat:@"%@?channel=%@&merchantId=%@&coinId=%@&amount=%@",urlPath,channel,merchantId,coinId,amount];
    //NSString *urlString = [NSString stringWithFormat:@"https://api.cospay.io/home/prepay?coinId=%@&amount=%@",coinId,amount];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSession *session=[NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask=[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud hide:YES];
            if(!error){
                NSString *orderInfo = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
                NSError *error;
                NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data
                                                                             options:NSJSONReadingMutableContainers
                                                                               error:&error];
                if (error==nil) {
                    NSInteger code = [responseDict[@"code"] integerValue];
                    if (code == 200) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSString *orderInfo = responseDict[@"data"];
                            NSLog(@"\rorderInfo:\r%@",orderInfo);
                            
                            //应用注册scheme,在PaySDKDemo-Info.plist定义URL types
                            NSString *appScheme = @"COSPaySDKDemo";
                            
                            //调用sdk开始支付
                            [[COSPaySDK defaultService] payOrder:orderInfo fromScheme:appScheme];
                            
                        });
                    }else {
                        NSLog(@"error:%@",@"server error");
                        [MBProgressHUD bwm_showTitle:@"server error" toView:self.view hideAfter:2];
                    }
                }
            } else {
                NSLog(@"error:%@",[error description]);
                [MBProgressHUD bwm_showTitle:[error description] toView:self.view hideAfter:2];
            }
        });
    }];
    
    //5.执行任务
    [dataTask resume];
}

#pragma mark -
#pragma mark   ==============点击模拟支付行为==============
-(void)doSimulationPay {
    
    //构造测试订单
    NSMutableDictionary *orderDic = [NSMutableDictionary dictionary];
    orderDic[@"amount"] = @"1.0000";
    orderDic[@"attach"] = @"api_prepay";
    orderDic[@"coinId"] = @"34190899187000";
    orderDic[@"merchantId"] = @"10000000000003";//商户id
    orderDic[@"orginAmount"] = @"0";
    orderDic[@"payBillNo"] = @"40476859839485";
    orderDic[@"refBizNo"] = @"2000010008";
    orderDic[@"toAddr"] = @"0x91f8654587917f3a0c7cfc5fa05bd86dc0162ddb";
    
    //生成订单信息及签名
    NSString* orderInfo = [self prepareOrderInfo:orderDic];
    NSLog(@"\rorderInfo:\r%@",orderInfo);
    
    //应用注册scheme,在PaySDKDemo-Info.plist定义URL types
    NSString *appScheme = @"COSPaySDKDemo";
    
    //调用sdk开始支付
    [[COSPaySDK defaultService] payOrder:orderInfo fromScheme:appScheme];
    
}

-(NSString*)prepareOrderInfo:(NSDictionary*)order
{
    
    NSArray* sortedKeys = [order.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSString *obj11 = obj1;
        NSString *obj22 = obj2;
        NSComparisonResult result = [obj11 compare:obj22];
        return result;
    }];
    
    NSMutableString* signInfo = [NSMutableString new];
    
    for(int i=0;i<sortedKeys.count;i++)
    {
        [signInfo appendFormat:@"%@=%@",sortedKeys[i],order[sortedKeys[i]]];
        
        if(i<sortedKeys.count-1)
            [signInfo appendString:@"&"];
    }
    
    NSLog(@"\rsignInfo:\r%@",signInfo);
    
    
    // 重要说明
    // 这里只是为了方便直接向商户展示COSPay的整个支付流程；所以Demo中加签过程直接放在客户端完成；
    // 真实App里，privateKey等数据严禁放在客户端，加签过程务必要放在服务端完成；
    // 防止商户私密数据泄露，造成不必要的资金损失，及面临各种安全风险；
    
    NSError* error = nil;
    NSString* merchantPrivateKeyFile = [[NSBundle mainBundle]pathForResource:@"partner_rsa_private_key" ofType:@"pem"];
    NSString* merchantPrivateKeyPEM = [NSString stringWithContentsOfFile:merchantPrivateKeyFile encoding:NSUTF8StringEncoding error:&error];
    
    DCPAPISigner* signer = [[DCPAPISigner alloc]initWithPrivateKey:merchantPrivateKeyPEM];
    
    NSData* dataForSign = [signInfo dataUsingEncoding:NSUTF8StringEncoding];
    NSData* signatureData = [signer sign:dataForSign];
    NSString* signatureBase64 = [signatureData base64EncodedString];
    
    NSLog(@"\signatureBase64:\r%@",signatureBase64);
    
    NSString* orderInfo = [NSString stringWithFormat:@"%@&sign=%@",signInfo,signatureBase64];
    
    return orderInfo;
}

#pragma mark -
#pragma mark   ==============处理支付结果==============
- (void)handlePayResult:(NSNotification *)notification {
    NSDictionary *resultDic = [notification object];
    int resultStatus = [resultDic[@"resultStatus"] intValue];
    NSString *message = resultDic[@"message"];
    [MBProgressHUD bwm_showTitle:message toView:self.view hideAfter:2];
}

@end
