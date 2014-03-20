//
//  ARTViewController.m
//  ARTurrets
//
//  Created by Marcin Pędzimąż on 04.03.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

#import "ARTRendererController.h"

#import "BulletManager.h"
#import "SoundSystem.h"

NSString * const kMetaioSDKLicense = @"LZ3Ma707rvdRF5gaWdvaujnTEPeZSIELyJZb2uqChlI=";
const CGFloat kMaxGeometryScale = 5.0f;
const CGFloat kMaxButtonGeometryScale = 50.0f;

//EXTERNAL ////////////////////////////////

BulletManager Bullets;
cSoundManager * SoundManager;
cListener * Listener;

float globalDT;

//////////////////////////////////////////

@interface ARTRendererController () <UIGestureRecognizerDelegate> {
    metaio::IGeometry*  m_redTurretBody;
    metaio::IGeometry*  m_blueTurretBody;
    
    metaio::IGeometry* m_redTurretCannon;
    metaio::IGeometry* m_blueTurretCannon;
    
    metaio::Vector3d blueCannonRotation;
    metaio::Vector3d redCannonRotation;
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) UIPanGestureRecognizer *redPanGesture;
@property (strong, nonatomic) UIPanGestureRecognizer *bluePanGesture;

- (void)setupGL;
- (void)tearDownGL;

@end

@implementation ARTRendererController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return [self shouldAutorotate] && ([self supportedInterfaceOrientations] & (1 << toInterfaceOrientation));
}

- (BOOL)shouldAutorotate
{
	return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    m_metaioSDK->setScreenRotation( metaio::getScreenRotationForInterfaceOrientation(interfaceOrientation) );
    
    // on ios5, we handle this in didLayoutSubView
	float version = [[[UIDevice currentDevice] systemVersion] floatValue];
	if( version < 5.0)
	{
		float scale = [UIScreen mainScreen].scale;
		m_metaioSDK->resizeRenderer(self.view.bounds.size.width*scale, self.view.bounds.size.height*scale);
	}
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
}

- (void)dealloc
{    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillResignActiveNotification
                                                  object:nil];
    
	[[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];

    [self removeTurretData];
    [self tearDownCustomRenderer];
    
    // delete sdk instance
    if( m_metaioSDK )
    {
        delete m_metaioSDK;
        m_metaioSDK = NULL;
    }
    
    // delete our sensors component
    if( m_sensors )
    {
        delete m_sensors;
        m_sensors = NULL;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }

    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if( m_metaioSDK )
    {
		std::vector<metaio::Camera> cameras = m_metaioSDK->getCameraList();
		if(cameras.size()>0)
		{
			m_metaioSDK->startCamera(cameras[0]);
		} else {
			NSLog(@"No Camera Found");
		}
    }
    
    // if we start up in landscape mode after having portrait before, we want to make sure that the renderer is rotated correctly
    UIInterfaceOrientation interfaceOrientation = self.interfaceOrientation;
    [self willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:0];
}

- (void)viewWillDisappear:(BOOL)animated
{
	if( m_metaioSDK )
    {
        m_metaioSDK->stopCamera();
    }
    
    [super viewWillDisappear:animated];
}

- (void)onApplicationWillResignActive:(NSDictionary*)userInfo
{
	if (m_metaioSDK)
    m_metaioSDK->pause();
}


- (void)onApplicationDidBecomeActive:(NSDictionary*)userInfo
{
	if (m_metaioSDK)
    m_metaioSDK->resume();
}

- (void) viewDidLayoutSubviews
{
	float scale = [UIScreen mainScreen].scale;
	m_metaioSDK->resizeRenderer(self.view.bounds.size.width*scale, self.view.bounds.size.height*scale);
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    // Create metaio SDK instance
    m_metaioSDK = metaio::CreateMetaioSDKIOS([kMetaioSDKLicense UTF8String]);
    if( !m_metaioSDK )
    {
        NSLog(@"SDK instance could not be created. Please verify the signature string");
        return;
    }
    
	// Listen to app pause/resume events because in those events we have to pause/resume the SDK
	
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onApplicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onApplicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    m_sensors = metaio::CreateSensorsComponent();
    
    if( !m_sensors )
    {
        NSLog(@"Could not create the sensors interface.");
        return;
    }
    
    m_metaioSDK->registerSensorsComponent( m_sensors );
    
    // initialize rendered for our sdk instance
    float scaleFactor = [UIScreen mainScreen].scale;
    metaio::Vector2d screenSize;
    screenSize.x = self.view.bounds.size.width * scaleFactor;
    screenSize.y = self.view.bounds.size.height * scaleFactor;
    
    m_metaioSDK->initializeRenderer(screenSize.x,
                                    screenSize.y,
                                    metaio::getScreenRotationForInterfaceOrientation(self.interfaceOrientation),
                                    metaio::ERENDER_SYSTEM_OPENGL_ES_2_0,
                                    (__bridge void*)_context);
    
    m_metaioSDK->enableBackgroundProcessing();
    
    // register our callback method for animations
    m_metaioSDK->registerDelegate(self);
    
    [self setupTurretData];
    [self setupTouchDetection];
    [self setupCustomRenderer];
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    globalDT = MAX(self.timeSinceLastUpdate, 0.0001);
    
    if (!m_metaioSDK) return;

    //attach poses to models
    
    std::vector<metaio::TrackingValues> poses = m_metaioSDK->getTrackingValues();
    
    if(poses.size()) {
        
        m_redTurretBody->setVisible(false);
        m_blueTurretBody->setVisible(false);
        
        for(int i = 0; i<poses.size(); i++) {
            
            metaio::TrackingValues trackingVal = poses[i];
            
            if (trackingVal.cosName == "blueone") {
                m_blueTurretBody->setCoordinateSystemID( trackingVal.coordinateSystemID );
                m_blueTurretBody->setVisible(true);
            }
            else if (trackingVal.cosName == "redone") {
                m_redTurretBody->setCoordinateSystemID( trackingVal.coordinateSystemID );
                m_redTurretBody->setVisible(true);
            }
            
        }
        
    }
    
    if (m_redTurretBody->isVisible()) {
        
        m_redTurretCannon->setRotation( metaio::Rotation( redCannonRotation ) );
    }

    if (m_blueTurretBody->isVisible()) {
        
        m_blueTurretCannon->setRotation( metaio::Rotation( blueCannonRotation ) );
    }
    
    ///////////CUSTOM RENDERER/////////////////
    
    Bullets . Simulate();

}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // tell sdk to render
    if( m_metaioSDK )
    {
        m_metaioSDK->render();
    }
    
    Bullets . Render();
    Bullets . DrawClouds();
    Bullets . DrawExplodes();
}

#pragma mark - Turret data

-(void) setupTurretData
{
    NSString* trackingDataFile = [[NSBundle mainBundle] pathForResource:@"trackingData"
																 ofType:@"xml"];
    
    if(trackingDataFile)
	{
		bool success = m_metaioSDK->setTrackingConfiguration([trackingDataFile UTF8String]);
		if( !success)
			NSLog(@"No success loading the tracking configuration");
	}
    
    
    NSString* baseTurretPath = [[NSBundle mainBundle] pathForResource:@"bottom"
															   ofType:@"obj"];
    
    NSString* cannotTurretPath = [[NSBundle mainBundle] pathForResource:@"top"
                                                                 ofType:@"obj"];
    
	if(baseTurretPath) {
        
        NSString* redTexturePath = [[NSBundle mainBundle] pathForResource:@"turret_2_red" ofType:@"png"];
        NSString* blueTexturePath = [[NSBundle mainBundle] pathForResource:@"turret_2_blue" ofType:@"png"];
        
		m_redTurretBody =  m_metaioSDK->createGeometry([baseTurretPath UTF8String]);
        m_redTurretCannon = m_metaioSDK->createGeometry([cannotTurretPath UTF8String]);
        
        if( m_redTurretBody ) {
            
            m_redTurretBody->setScale(metaio::Vector3d(kMaxGeometryScale,kMaxGeometryScale,kMaxGeometryScale));
            m_redTurretBody->setRotation( metaio::Rotation( metaio::Vector3d(M_PI_2,0,0) ) );
            m_redTurretBody->setRotation( metaio::Rotation( metaio::Vector3d(0,0,-M_PI_2) ), true);
            
            
            if (redTexturePath) {
                m_redTurretBody->setTexture([redTexturePath UTF8String]);
            }
            
            if (redTexturePath) {
                m_redTurretCannon->setTexture([redTexturePath UTF8String]);
            }
            
            m_redTurretCannon->setParentGeometry(m_redTurretBody);
            m_redTurretCannon->setTranslation( metaio::Vector3d(0, 25, 0) ,true);
            
        }
        else {
            
            NSLog(@"m_redTurretGeometry: error, could not load %@", baseTurretPath);
        }
        
        m_blueTurretBody =  m_metaioSDK->createGeometry([baseTurretPath UTF8String]);
        m_blueTurretCannon = m_metaioSDK->createGeometry([cannotTurretPath UTF8String]);
        
        if( m_blueTurretBody ) {
            
            m_blueTurretBody->setScale(metaio::Vector3d(kMaxGeometryScale,kMaxGeometryScale,kMaxGeometryScale));
            m_blueTurretBody->setRotation( metaio::Rotation( metaio::Vector3d(M_PI_2,0,0) ) );
            m_blueTurretBody->setRotation( metaio::Rotation( metaio::Vector3d(0,0,M_PI_2) ), true);
        
            if (blueTexturePath) {
                m_blueTurretBody->setTexture([blueTexturePath UTF8String]);
            }
            
            if (blueTexturePath) {
                m_blueTurretCannon->setTexture([blueTexturePath UTF8String]);
            }
            
            m_blueTurretCannon->setParentGeometry(m_blueTurretBody);
            m_blueTurretCannon->setTranslation( metaio::Vector3d(0, 25, 0) ,true);
            
        }
        else {
            
            NSLog(@"m_blueTurretGeometry: error, could not load %@", baseTurretPath);
        }
        
        redCannonRotation = metaio::Vector3d(0,0,0);
        blueCannonRotation = metaio::Vector3d(0,0,0);
    }

}

-(void) removeTurretData
{
    m_metaioSDK->unloadGeometry(m_blueTurretBody);
    m_metaioSDK->unloadGeometry(m_redTurretBody);
    
    m_metaioSDK->unloadGeometry(m_redTurretCannon);
    m_metaioSDK->unloadGeometry(m_blueTurretCannon);
}

-(void) setupTouchDetection
{
    self.redPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(viewdidPan:)];
    self.bluePanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(viewdidPan:)];
    
    self.redPanGesture.delegate = self;
    self.bluePanGesture.delegate = self;
    
    [self.view addGestureRecognizer:self.redPanGesture];
    [self.view addGestureRecognizer:self.bluePanGesture];
}

-(void) setupCustomRenderer
{
    Bullets.m_metaioSDK = m_metaioSDK;
    
    SoundManager = new cSoundManager();
    Listener = new cListener();
    
    //==================================================================
  
    SoundManager -> GetSound( "whooo" , "whooo" );
    SoundManager -> GetSound( "kaboom" , "kaboom" );
    SoundManager -> GetSound( "shoot" , "shoot" );
    SoundManager -> GetSound( "fire" , "fire" );
}

-(void) shootBullet:(BOOL) redTurret
{
    metaio::IGeometry* model = NULL;
    metaio::IGeometry* body = NULL;
    
    int gemetryID = 0;
    
    if (redTurret) {
        model = m_redTurretCannon;
        body  = m_redTurretBody;
        gemetryID = m_redTurretBody->getCoordinateSystemID();
    }
    else{
        model = m_blueTurretCannon;
        body = m_blueTurretBody;
        gemetryID = m_blueTurretBody->getCoordinateSystemID();
    }
    
    metaio::Vector3d position = model->getTranslation();
    
    metaio::Vector3d eulerAngles = model->getRotation().getEulerAngleRadians();
    metaio::Vector3d eulerTracking = body->getRotation().getEulerAngleRadians();
    
    const float kMaxBulletSpeed = 600.0f;
    
    float bx = position.x;
    float by = position.y;
    float bz = position.z+100;
    
    float ax = kMaxBulletSpeed * cos( eulerTracking.z ) * cos( eulerAngles.z );
    float ay = -kMaxBulletSpeed * sin( eulerTracking.z ) * cos( eulerAngles.z );
    float az = -kMaxBulletSpeed * sin( eulerAngles.z );
    
    Bullet * bullet = new Bullet( bx , by , bz, ax, ay, az , m_metaioSDK, gemetryID);

    Bullets . AddBullet( bullet );
    
    SoundManager -> GetSound( "shoot" ) -> PlayAt( xVec3(position.x, position.y , position.z) , 1.0f , 0.1f );
    
}

-(void) tearDownCustomRenderer
{
    Bullets.RemoveAllObjects();
   
    delete Listener;
    delete SoundManager;
}

#pragma mark - Touch event handling

-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan: touches withEvent: event];
    
    UITouch *touch = [touches anyObject];
    CGPoint loc = [touch locationInView:self.view];
	
    float scale = self.view.contentScaleFactor;
    
    metaio::IGeometry* model = m_metaioSDK->getGeometryFromScreenCoordinates(loc.x * scale, loc.y * scale, false);
	
    if (model) {
        
        BOOL isRedTurret = NO;
        
        if (model == m_redTurretBody || model == m_redTurretCannon) {
            isRedTurret = YES;
        }
        
        [self shootBullet:isRedTurret];
    }
}

#pragma mark - MetaioSDKDelegate method implementation

- (void) onTrackingEvent:(const metaio::stlcompat::Vector<metaio::TrackingValues>&)trackingValues
{

}

#pragma mark - Gesture Recognizers 

-(BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{

    CGPoint pos = [touch locationInView:self.view];
    
    std::vector<metaio::TrackingValues> poses = m_metaioSDK->getTrackingValues();
    
    static float halfScreenSize = self.view.frame.size.width*0.5f;
    
    if (poses.size()) {
        
        for(int i = 0; i<poses.size(); i++) {
            
            metaio::TrackingValues trackingVal = poses[i];
            
            if ( (gestureRecognizer == self.bluePanGesture && trackingVal.cosName == "blueone") ||
                 (gestureRecognizer == self.redPanGesture && trackingVal.cosName == "redone") ) {
                
                if (trackingVal.quality > 0.0) {
                    
                    metaio::Vector2d markerpos = m_metaioSDK->getScreenCoordinatesFrom3DPosition(trackingVal.coordinateSystemID, trackingVal.translation, true);
                    
                    if ( (pos.x > halfScreenSize && markerpos.x > halfScreenSize) ||
                         (pos.x < halfScreenSize && markerpos.x < halfScreenSize) ) {
                        
                        return YES;
                    }
                    else {
                        
                        return NO;
                    }
                }
                else {
                    return NO;
                }
                
            }
            else {
                return YES;
            }
        
        }
        
    }
    else{
        return NO;
    }

    return YES;
}

-(void) viewdidPan:(UIPanGestureRecognizer*)recognizer
{
    if(recognizer.state == UIGestureRecognizerStateEnded){
  
    }
    else if(recognizer.state == UIGestureRecognizerStateBegan){
        
    }
    else {
        
        const CGFloat kMaxRotationBias = M_PI_4;
        CGFloat distanceOffset = M_PI_2 * self.timeSinceLastUpdate;
        
        CGPoint trans = [recognizer translationInView:self.view];
        
        if (recognizer == self.redPanGesture) {
            
            if (trans.y > 0) {
                redCannonRotation.z += distanceOffset;
            }
            else{
                redCannonRotation.z -= distanceOffset;
            }
        }
        else if(recognizer == self.bluePanGesture){
        
            if (trans.y > 0) {
                blueCannonRotation.z += distanceOffset;
            }
            else{
                blueCannonRotation.z -= distanceOffset;
            }
        }
        
        if (redCannonRotation.z > kMaxRotationBias) {
            redCannonRotation.z = kMaxRotationBias;
        }
        else if(redCannonRotation.z < -kMaxRotationBias) {
            redCannonRotation.z = -kMaxRotationBias;
        }
        
        if (blueCannonRotation.z > kMaxRotationBias) {
            blueCannonRotation.z = kMaxRotationBias;
        }
        else if(blueCannonRotation.z < -kMaxRotationBias) {
            blueCannonRotation.z = -kMaxRotationBias;
        }

    }
}

@end
