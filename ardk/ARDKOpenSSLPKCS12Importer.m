//
//  ARDKOpenSSLPKCS12Importer.m
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#if !defined(SODK_EXCLUDE_OPENSSL_PDF_SIGNING)

#import "ARDKOpenSSLPKCS12Importer.h"
#import "ARDKOpenSSLKeychain.h"

@interface ARDKOpenSSLPKCS12Importer ()
@end

static NSString * const PKCS12_FILE_SUFFIX_P12SO = @"p12so";
static NSString * const PKCS12_FILE_SUFFIX_PFXSO = @"pfxso";
static const int maxPasswordRetries = 5;

@implementation ARDKOpenSSLPKCS12Importer

// Imports the PKCS12 file "url" url into the keychain, interacts with the user
// to get the password required to decrypt the file, parentViewController acts
// as the parent of the dialog presented to recover the password from the user
-(void) importToKeychain:(NSURL *) url
    parentViewController:(UIViewController *)parentViewController
    
{
    [self getFilePasswordFromUser:url
             parentViewController:parentViewController
                       retryCount:0
                        onSuccess:^(NSString *password)
          {
              [self importToKeychain:url
                            password:password];
          }];
}

// Imports the data in the PKCS12 file "url" into the keychain,
// "password" is used to decrypt the file
-(void) importToKeychain:(NSURL *) url
                password:(NSString *) password
{
    if ( url &&
         password )
    {
        CFArrayRef secItems = NULL;
        if ([self getSecItems:url
                     password:password
                     secItems:&secItems])
        {
            for(CFIndex i = 0; i < CFArrayGetCount(secItems); i++)
            {
                NSDictionary *nsDict = (__bridge NSDictionary *) CFArrayGetValueAtIndex(secItems, i);
                if (nsDict)
                {
                    NSLog(@"Importing the following items into this app's iOS keychain: %@", nsDict);

                    // There is a SecTrustRef in here, we can ignore this for now, it can't be
                    // imported into the keychain anyway. We may use it in the future if we want
                    // to check if the certificate we're imported is trusted
                    SecTrustRef trust = (__bridge SecTrustRef) nsDict[ (__bridge id) kSecImportItemTrust ];
                    (void)trust; // suppress unused variable warning from the compiler
                  
                    SecIdentityRef identity = (__bridge SecIdentityRef) nsDict[ (__bridge id) kSecImportItemIdentity ];
                    
                    // The documentation says we should supply a (kSecClass, kSecClassIdentity) key/value pair to this
                    // query, but when I do, the Identity and Key added fail to be delivered when we query
                    // for them later with a call to SecItemCopyMatching(). So we'll omit the (kSecClass, kSecClassIdentity)
                    // key/value pair from this query for now. This looks like a bug in the Apple Security API
                    NSDictionary* addIdentityQuery = @{ 
                        (__bridge id) kSecValueRef:   (__bridge id) identity
                    };
                    
                    OSStatus addIdentityResult = SecItemAdd((__bridge CFDictionaryRef) addIdentityQuery, NULL);
                    if (addIdentityResult == errSecSuccess)
                    {
                        CFArrayRef chain = (__bridge CFArrayRef) nsDict[ (__bridge id)kSecImportItemCertChain ];

                        for(CFIndex c = 0; c < CFArrayGetCount(chain); c++)
                        {
                            SecCertificateRef cert = (SecCertificateRef) CFArrayGetValueAtIndex(chain, c);
                            if (cert)
                            {
                                NSDictionary* addCertQuery = @{
                                    (__bridge id) kSecClass:      (__bridge id) kSecClassCertificate,
                                    (__bridge id) kSecValueRef:   (__bridge id) cert
                                };
                                
                                OSStatus addCertResult = SecItemAdd((__bridge CFDictionaryRef) addCertQuery, NULL);
                                if (addCertResult != errSecSuccess)
                                {
                                    NSLog(@"Error: %s SetItemAdd() for certificate returns error (%d) '%@'",
                                          __PRETTY_FUNCTION__,
                                          addCertResult,
                                          [ARDKOpenSSLKeychain SecAPI_errorToString:addCertResult]);
                                }
                            }
                        }
                    }
                    else
                    {
                        NSLog(@"Error: %s SetItemAdd() for identity returns error (%d) '%@'",
                              __PRETTY_FUNCTION__,
                              addIdentityResult,
                              [ARDKOpenSSLKeychain SecAPI_errorToString:addIdentityResult]);
                    }
                }
            }
        }

        if (secItems)
        {
            CFRelease(secItems);
            secItems = NULL;
        }
    }
    else
    {
        NSLog(@"Error: %s invalid argument url=%p password=%p",
              __PRETTY_FUNCTION__,
              url,
              password);
    }
}

// Returns YES if url points to a PKCS12 file "url", otherwise returns NO
-(BOOL) isPKCS12File:(NSURL *) url
{
    NSString *ext = url.pathExtension;
    if( ([ext caseInsensitiveCompare:PKCS12_FILE_SUFFIX_P12SO] == NSOrderedSame) ||
        ([ext caseInsensitiveCompare:PKCS12_FILE_SUFFIX_PFXSO] == NSOrderedSame) )
    {
        return YES;
    }

    return NO;
}

// Returns YES if this password successfully decrypts the PKSC12 file "url", otherwise returns NO
-(BOOL) validateFilePassword:(NSURL *) url
                    password:(NSString *) password
{
    BOOL result = NO;

    if (url && password)
    {
        CFArrayRef secItems = NULL;
        if ([self getSecItems:url
                     password:password
                     secItems:&secItems])
        {
            result = YES;
        }
        
        if (secItems)
        {
            CFRelease(secItems);
            secItems = NULL;
        }
    }
    else
    {
        NSLog(@"Error: %s invalid argument url=%p password=%p",
              __PRETTY_FUNCTION__,
              url,
              password);
    }

    return result;
}

-(void) getFilePasswordFromUser:(NSURL *) url
           parentViewController:(UIViewController *)parentViewController
                     retryCount:(int) retryCount
                      onSuccess:(void (^)(NSString *)) successBlock
{
    if (url.fileURL)
    {
        UIAlertController *alertController = nil;
        
        if (retryCount > maxPasswordRetries)
        {
            NSString *title = NSLocalizedString(@"Password for PKCS12 file: '%@'",
                                                @"Prompt to ask the user for the password for the file PKCS12 file %@ being imported");
            
            NSString *message = NSLocalizedString(@"Too many password retry attempts",
                                                  @"Prompt to ask tell the user that they have run out of password retry attempts");
            
            alertController = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:title, [url lastPathComponent]]
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil)
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction * _Nonnull action) {}];
            
            [alertController addAction:cancelAction];
        }
        else
        {
            NSString *title = NSLocalizedString(@"Password for PKCS12 file: '%@'",
                                                @"Prompt to ask the user for the password for the file PKCS12 file %@ being imported");
            
            NSString *message = (retryCount > 0) ? NSLocalizedString(@"Invalid password, please try again",
                                                                     @"Prompt to ask tell the user that the PKCS12 password was incorrect, and to try again") : nil;
            
            alertController = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:title, [url lastPathComponent]]
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                    textField.placeholder = @"";
                    textField.secureTextEntry = YES;
                }];
            
            UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * _Nonnull action) {
                    NSString *password = [[alertController textFields][0] text];
                    
                    if ([self validateFilePassword:url
                                          password:password])
                    {
                        successBlock(password);
                    }
                    else
                    {
                        // async call of this method to allow the user to retry
                        dispatch_async(dispatch_get_main_queue(),
                                       ^{
                                            [self getFilePasswordFromUser:url
                                                     parentViewController:parentViewController
                                                               retryCount:(retryCount + 1)
                                                                onSuccess:successBlock];
                                       });
                        
                    }
                }];
            
            [alertController addAction:confirmAction];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction * _Nonnull action) {}];
            
            [alertController addAction:cancelAction];
        }
        
        if (parentViewController && alertController)
        {
            [parentViewController presentViewController:alertController
                                               animated:YES
                                             completion:nil];
        }
    }
}

// Reads the PKSC12 file 'url' returns the identities and certificates in "secItems"
// Returns YES if successful, otherwise NO. The caller is responsible for calling
// "CFRelease()" on the value returned in "secItems"
-(BOOL) getSecItems:(NSURL *) url
           password:(NSString *) password
           secItems:(CFArrayRef *) secItems 
{
    BOOL result = NO;
    
    if (url.fileURL &&
        password &&
        secItems)
    {
        NSString *path = [url path];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path] )
        {
            NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
            CFDataRef cfData = CFDataCreate(NULL, [data bytes], [data length]); 
            if (cfData)
            {
                OSStatus importResult = errSecSuccess;
                NSDictionary *optionsDict = @{
                    (__bridge id) kSecImportExportPassphrase:  password
                };
                
                importResult = SecPKCS12Import(cfData,
                                               (__bridge CFDictionaryRef)optionsDict,
                                               secItems);
                if (importResult == errSecSuccess)
                {
                    result = YES;
                }
                else if (importResult == errSecAuthFailed)
                {
                    NSLog(@"Error: %s failed due to a bad password, prompt the user to try again",
                          __PRETTY_FUNCTION__);
                }
                else
                {
                    NSLog(@"Error: %s returns error (%d) '%@'",
                          __PRETTY_FUNCTION__,
                          importResult,
                          [ARDKOpenSSLKeychain SecAPI_errorToString:importResult]);
                }

                CFRelease(cfData);
                cfData = NULL;
            }
        }
        else
        {
            NSLog(@"Error: %s - the file '%s' does not exist",
                  __PRETTY_FUNCTION__,
                  [path UTF8String]);
        }
    }
    else
    {
        NSLog(@"Error: %s invalid argument url=%p password=%p",
              __PRETTY_FUNCTION__,
              url,
              password);
    }

    return result;
}

@end

#endif // SODK_EXCLUDE_OPENSSL_PDF_SIGNING
