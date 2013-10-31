#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#import <GTWSWBase/GTWSWBase.h>

@interface GTWAddressBookTripleStore : NSObject<GTWTripleStore>

@property ABAddressBook* ab;

- (instancetype) initWithDictionary: (NSDictionary*) dictionary;

@end
