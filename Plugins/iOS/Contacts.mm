//
//  Contacts.m
//  ContactsList
//
//  Created by Apple on 8/4/14.
//  Copyright (c) 2014 DreamMakers. All rights reserved.
//

#import "Contacts.h"
#import <AddressBook/AddressBook.h>
#import <Contacts/Contacts.h>
//#import <AddressBook/AddressBook.h>
#include<pthread.h>

@implementation Contacts


@end



// Helper method to create C string copy
char* aliessmael_MakeStringCopy (const char* string)
{
    if (string == NULL)
        return NULL;
    
    char* res = (char*)malloc(strlen(string) + 1);
    strcpy(res, string);
    return res;
}

@interface ContactItem :NSObject
{
@public ABRecordRef person;
    
@public NSString *name ;
@public ABMultiValueRef phoneNumbersRef;
@public NSMutableArray *phoneNumber;
@public NSMutableArray *phoneNumberType;
@public NSMutableArray *emails;
@public NSData* image;
};
@end
@implementation ContactItem


@end
extern "C" {
    CFIndex nPeople;
    CFArrayRef allPeople;
    NSMutableArray* contactItems;
    ABAddressBookRef addressBook;
    CNContactStore *MiContactAddresBook ;
    
    
    NSArray *DatosParaSacar = @[CNContactEmailAddressesKey,
                                CNContactFamilyNameKey,
                                CNContactGivenNameKey,
                                CNContactPhoneNumbersKey,
                                CNContactPostalAddressesKey];
    
    NSMutableArray *grupoTodosLosContactos;
    
    
    void contact_log( const char* message)
    {
        UnitySendMessage("ContactsListMessageReceiver", "Log", message );
    }
    
    void contact_error( char* error)
    {
        UnitySendMessage("ContactsListMessageReceiver", "Error", error );
    }
    
    void contact_loadName( ContactItem* c )
    {
        NSString* firstName = (__bridge NSString *)(ABRecordCopyValue(c->person,kABPersonFirstNameProperty));
        NSString* lastName = (__bridge NSString *)(ABRecordCopyValue(c->person, kABPersonLastNameProperty));
        
        NSString* f = ( firstName == NULL)?[[NSString alloc]init]:firstName ;
        NSString* s = ( lastName == NULL)?[[NSString alloc]init]:lastName ;
        
        c->name = [NSString stringWithFormat:@"%@ %@",f,s];
        //c->name = aliessmael_MakeStringCopy([name UTF8String]);
        //return aliessmael_MakeStringCopy([name UTF8String]);
    }
    
    void contact_loadPhoneNumbers( ContactItem* c )
    {
        c->phoneNumbersRef = ABRecordCopyValue(c->person, kABPersonPhoneProperty);
        long phonesCount = ABMultiValueGetCount(c->phoneNumbersRef);
        c->phoneNumber = [NSMutableArray new];
        c->phoneNumberType = [NSMutableArray new];
        for (CFIndex i = 0; i < phonesCount ;i++) {
            NSString *phoneNumber = (__bridge NSString *) ABMultiValueCopyValueAtIndex(c->phoneNumbersRef, i);
            [c->phoneNumber addObject:phoneNumber];
            
            CFStringRef locLabel = ABMultiValueCopyLabelAtIndex(c->phoneNumbersRef, i);
            NSString* phoneLabel = (__bridge NSString*) ABAddressBookCopyLocalizedLabel(locLabel);
            [c->phoneNumberType addObject:phoneLabel];
        }
    }
    
    void contact_loadEmails( ContactItem* c )
    {
        c->emails = [NSMutableArray new];
        ABMultiValueRef emails = ABRecordCopyValue(c->person, kABPersonEmailProperty);
        for (CFIndex j=0; j < ABMultiValueGetCount(emails); j++) {
            NSString* email = ( __bridge NSString*)ABMultiValueCopyValueAtIndex(emails, j);
            [c->emails addObject:email];
            //[email release];
        }
        CFRelease(emails);
    }
    
    void contact_loadPhoto( ContactItem* c )
    {
        UIImage *img = nil;
        c->image = nil;
        if (c->person != nil && ABPersonHasImageData(c->person)) {
            if ( &ABPersonCopyImageDataWithFormat != nil ) {
                NSData * data = (__bridge NSData *)ABPersonCopyImageDataWithFormat(c->person, kABPersonImageFormatThumbnail);
                
                c->image = data;
                
            } else {
                NSData * data = (__bridge NSData *)ABPersonCopyImageData(c->person);
                c->image = data;
                
            }
            //CFRelease( img );
            
        } else {
            img= nil;
            c->image = nil;
        }
        
    }
    
    void contact_writeString( NSOutputStream *oStream, NSString* str )
    {
        if( str == NULL )
        {
            short size = 0;
            [oStream write:(uint8_t *)&size maxLength:2];
        }
        else
        {
            const char* data = [str UTF8String];
            short size = strlen( data);
            //short size = sizeof(data)/ sizeof(char);
            [oStream write:(uint8_t *)&size maxLength:2];
            [oStream write:(uint8_t *)data maxLength:size];
            
        }
    }
    
    const char* contact_toBytes( ContactItem* c )
    {
        
        NSOutputStream *oStream = [[NSOutputStream alloc] initToMemory];
        [oStream open];
        
        contact_writeString( oStream, NULL);//native id
        contact_writeString( oStream, c->name );
        
        short size = 0;
        short size2 = 0;
        if( c->image == NULL)
        {
            [oStream write:(uint8_t *)&size maxLength:2];
        }
        else
        {
            size = c->image.length;
            [oStream write:(uint8_t *)&size maxLength:2];
            uint8_t * data = (uint8_t *)[c->image bytes];
            [oStream write: data maxLength:size];
        }
        
        if( c->phoneNumber == NULL)
        {
            size = 0;
            [oStream write:(uint8_t *)&size maxLength:2];
        }
        else
        {
            size = c->phoneNumber.count;
            size2 = c->phoneNumberType.count;
            [oStream write:(uint8_t *)&size maxLength:2];
            for (int i = 0; i < size; i++)
            {
                NSString* text1 = [c->phoneNumber objectAtIndex:i];
                contact_writeString( oStream, text1 );
                if( i < size2){
                    NSString* text2 = [c->phoneNumberType objectAtIndex:i];
                    contact_writeString( oStream, text2 );
                }
            }
        }
        
        if( c->emails == NULL)
        {
            size = 0;
            [oStream write:(uint8_t *)&size maxLength:2];
        }
        else
        {
            size = c->emails.count;
            [oStream write:(uint8_t *)&size maxLength:2];
            for (int i = 0; i < size; i++)
            {
                NSString* text = [c->emails objectAtIndex:i];
                contact_writeString( oStream, text );
                contact_writeString( oStream, NULL );
            }
        }
        
        size = 0;
        [oStream write:(uint8_t *)&size maxLength:2];
        
        
        
        NSData *contents = [oStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        [oStream close];
        NSString* str = [contents base64Encoding];
        return [str UTF8String];
    }
    
    char* getContact( int index )
    {
        //NSString* d = [NSString stringWithFormat:@"Get contact of index : %d", index];
        //contact_log([d UTF8String]);
        ContactItem* c = [contactItems objectAtIndex:index];
        const char* data = contact_toBytes(c);
        return aliessmael_MakeStringCopy(data) ;
    }
    
    void* parseContactWithContact (CNContact* contact, ContactItem* ci)
    {
        NSString* firstName =  contact.givenName;
        NSString* lastName =  contact.familyName;
        // NSString* phone = [[contact.phoneNumbers valueForKey:@"value"] valueForKey:@"digits"];
        CNLabeledValue *emailValue = contact.emailAddresses.firstObject;
        //NSString *emailString = email.value;
        NSString* email = emailValue.value;
        
        NSArray <CNLabeledValue<CNPhoneNumber *> *> *phoneNumbers = contact.phoneNumbers;
        CNLabeledValue<CNPhoneNumber *> *firstPhone = [phoneNumbers firstObject];
        CNPhoneNumber *number = firstPhone.value;
        NSString *digits = number.stringValue; // 1234567890
        NSString *label = firstPhone.label; // Mobile
        
        //NSArray * addrArr = [self parseAddressWithContac:contact];
        ci->name = [NSString stringWithFormat:@"%@ %@",firstName,lastName];
        ci->phoneNumber = [NSMutableArray new];
        
        ci->phoneNumberType = [NSMutableArray new];
        ci->emails = [NSMutableArray new];
        
        
        if (digits.length > 0)
        {
            [ci->phoneNumber addObject:digits];
        }
        if (label.length > 0)
        {
            [ci->phoneNumberType addObject:label];
        }
        if (email.length > 0)
        {
            [ci->emails addObject:email];
        }
        // [ci->emails addObject:@"5555 666 777@ccc.com"];
        
        ci->image = nil;
        
        //NSLog( @" ------------ nombre: %@ correo; --%@ %d|%@ %d--" , ci->name,digits,digits.length,label,label.length);
        
        //return 0;
    }
    
    void* contact_load_thread( void *arg)
    {
        //ABRecordRef source = ABAddressBookCopyDefaultSource(addressBook);
        /*allPeople = ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering(addressBook, nil, kABPersonSortByFirstName);
         nPeople = ABAddressBookGetPersonCount( addressBook );*/
        // NSLog( @"error %@" , *error );
        // NSLog( @"cont %ld" , nPeople );
        MiContactAddresBook = [[CNContactStore alloc]init];
        
        CNContactFetchRequest *fechRequest = [[CNContactFetchRequest alloc] initWithKeysToFetch:DatosParaSacar];
        
        __block int i =0;
        contactItems = [NSMutableArray new];
        
        [MiContactAddresBook enumerateContactsWithFetchRequest:fechRequest error:nil
                                                    usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
                                                        //[];
                                                        
                                                        ContactItem* ci = [[ContactItem alloc]init];
                                                        //NSLog( @"contact %d is empty" , contact );
                                                        parseContactWithContact(contact,ci);
                                                        
                                                        [contactItems addObject:ci];
                                                        
                                                        NSString *idStr = [NSString stringWithFormat:@"%d",i];
                                                        const char* _idStr = [idStr UTF8String] ;
                                                        //contact_log( _idStr);
                                                        NSLog( @" -------- ++++ i: %@" , idStr );
                                                        NSLog( @" ------------ nombre: %@ " , ci->name );
                                                        UnitySendMessage("ContactsListMessageReceiver", "OnContactReady", _idStr);
                                                        
                                                        i= i+1;
                                                        
                                                    } ];
        /*for ( int i = 0; i < nPeople; i++ )
         {
         ContactItem* c = [[ContactItem alloc]init];
         c->person = CFArrayGetValueAtIndex( allPeople, i );
         if( c->person == nil)
         {
         NSLog( @"contact %d is empty" , i );
         continue;
         }
         
         contact_loadName( c );
         
         contact_loadPhoneNumbers( c);
         
         contact_loadEmails( c );
         
         contact_loadPhoto( c );
         
         
         [contactItems addObject:c];
         
         NSString *idStr = [NSString stringWithFormat:@"%d",i];
         const char* _idStr = [idStr UTF8String] ;
         //contact_log( _idStr);
         
         UnitySendMessage("ContactsListMessageReceiver", "OnContactReady", _idStr);
         
         }*/
        UnitySendMessage("ContactsListMessageReceiver", "OnInitializeDone","");
        
        
        
        /*CFRelease(addressBook);
         CFRelease(allPeople);
         addressBook = NULL;*/
        //return 0:
    }
    
    pthread_t thread = NULL;
    void contact_listContacts()
    {
        pthread_create(&(thread), NULL, &contact_load_thread, NULL);
    }
    
    void loadIOSContacts()
    {
        ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
        if (status == kABAuthorizationStatusDenied) {
            // if you got here, user had previously denied/revoked permission for your
            // app to access the contacts, and all you can do is handle this gracefully,
            // perhaps telling the user that they have to go to settings to grant access
            // to contacts
            NSLog(@"permissin issu");
            [[[UIAlertView alloc] initWithTitle:nil message:@"This app requires access to your contacts to function properly. Please visit to the \"Privacy\" section in the iPhone Settings app." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            
            UnitySendMessage("ContactsListMessageReceiver", "OnInitializeFail","kABAuthorizationStatusDenied");
            
            return;
        }
        CFErrorRef *error = NULL;
        addressBook = ABAddressBookCreateWithOptions(NULL, error );
        if (error) {
            NSLog(@"error: %@", CFBridgingRelease(error));
            if (addressBook)
                CFRelease(addressBook);
            UnitySendMessage("ContactsListMessageReceiver", "OnInitializeFail","Can not create addressbook");
            return;
        }
        if (status == kABAuthorizationStatusNotDetermined)
        {
            
            // present the user the UI that requests permission to contacts ...
            
            ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
                if (granted) {
                    // if they gave you permission, then just carry on
                    
                    contact_listContacts();
                }
                else
                {
                    // however, if they didn't give you permission, handle it gracefully, for example...
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // BTW, this is not on the main thread, so dispatch UI updates back to the main queue
                        
                        [[[UIAlertView alloc] initWithTitle:nil message:@"This app requires access to your contacts to function properly. Please visit to the \"Privacy\" section in the iPhone Settings app." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                    });
                    UnitySendMessage("ContactsListMessageReceiver", "OnInitializeFail","kABAuthorizationStatusNotDetermined");
                }
                
                //CFRelease(addressBook);
            });
        }
        else if( status == kABAuthorizationStatusAuthorized )
        {
            contact_listContacts();
        }
        else
        {
            UnitySendMessage("ContactsListMessageReceiver", "OnInitializeFail","unknown issue");
        }
        
    }
    
}













