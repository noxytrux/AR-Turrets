//
//  ARTViewController.h
//  ARTurrets
//
//  Created by Marcin Pędzimąż on 04.03.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <metaioSDK/IMetaioSDKIOS.h>

@interface ARTRendererController : GLKViewController <MetaioSDKDelegate> {

    metaio::IMetaioSDKIOS*	m_metaioSDK;			//!< Reference to metaio SDK
    metaio::ISensorsComponent*		m_sensors;			//!< Pointer to our sensors manager

}

@end
