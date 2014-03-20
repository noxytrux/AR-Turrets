#ifndef BULLETS_H
#define BULLETS_H

#include "SoundSystem.h"
#import <metaioSDK/IMetaioSDKIOS.h>

class Bullet
{

public:
    
    metaio::IMetaioSDKIOS*	m_metaioSDK;
    
    metaio::Vector3d Pos;
    metaio::Vector3d Acc;

    int NumLast;
    int C;

    float T;
    float balisticRotation;

    Sound *sound;
 
    xVec3 lPos;
    xQuat quaternion;
    xQuat quaternion2;
    xQuat quaternion3;
    float OY;
    float OX;
    
    metaio::IGeometry *m_bulletMesh;
    
    ~Bullet() {
        m_metaioSDK->unloadGeometry(m_bulletMesh);
    }
    
    
	// konstruktor
    Bullet( float x, float y, float z, float ax, float ay, float az , metaio::IMetaioSDKIOS *SDK, int trackingID)
    {
        balisticRotation = 0;
        
        NSString* bulletPath = [[NSBundle mainBundle] pathForResource:@"tank_bullet_01" ofType:@"obj"];
        NSString* texturePath = [[NSBundle mainBundle] pathForResource:@"tank_bullet_01" ofType:@"png"];
        
        m_metaioSDK = SDK;
        m_bulletMesh = SDK->createGeometry([bulletPath UTF8String]);
        
        Pos = metaio::Vector3d(x,y,z);
        Acc = metaio::Vector3d(ax,ay,az);
    
        if(m_bulletMesh){
            
            m_bulletMesh->setCoordinateSystemID(trackingID);
            m_bulletMesh->setScale(metaio::Vector3d(1.0,1.0,1.0));
            m_bulletMesh->setTexture([texturePath UTF8String]);
            m_bulletMesh->setTranslation(Pos);
            
            m_bulletMesh->setCoordinateSystemID(-1);
            
            m_bulletMesh->setRotation( metaio::Rotation( metaio::Vector3d(M_PI_2,0,0) ) );
            m_bulletMesh->setRotation( metaio::Rotation( metaio::Vector3d(0,0,M_PI_2) ), true);
            
        }
        
        lPos = xVec3(Pos.x, Pos.y, Pos.z);
        
        NumLast = 0;
        C = 0;

        T = 0.0f;
        sound = NULL;
    }

	// ruch pocisku
    bool Simulate()
    {
		
        Pos += Acc * globalDT; // akceleracja
        
        Acc.x *= 0.98f;
        Acc.y *= 0.98f;
        Acc.z -= 75.0 * globalDT; // druga pochodna dla spadku kuli
        
        if( Acc.z < 0.0f ){ // jeœli kula spada
            
            xVec3 pPos = xVec3(Pos.x,Pos.y, Pos.z);
            
            if( sound == NULL ){ // i nie ma dŸwiêku
                sound = SoundManager -> GetSound( "whooo" );// odegraj g³os spadania kuli
                sound-> PlayAt( pPos , 1.0f );
            }
            
            
            sound -> Update( pPos ); // aktualizuj pozycje dxwieku
        }

        T += globalDT;
        
        balisticRotation += globalDT * 8.0;
        
        m_bulletMesh->setTranslation(Pos);

        if( T > 60 || Pos.z < 0.0 ) // jeœli kula spad³a
        {

            if(sound) sound -> Stop(); // wycisz g³os spadania
            return true;

        }

        return false;

    }
	
    void Destroy()
    {
        Pos.z = -2.0;
    }

	// renderowanie kuli
    void Render()
    {
  
        xVec3 rPos = xVec3(Pos.x, Pos.y, Pos.z);
        xVec3 dir = rPos-lPos;
        lPos = rPos;
        dir.normalize();
     
        OY = atan2( -dir.z , dir.x );
        OX = atan2(  dir.y , sqrt( dir . x * dir . x + dir . z * dir . z ) );

        quaternion.fromEulerAngles( 0, OY, 0 ) ;
        quaternion2.fromEulerAngles( 0, 0, OX );
        quaternion3.fromEulerAngles( balisticRotation, 0, 0 ) ;

        xQuat outputQuat = quaternion * quaternion2 * quaternion3;
        
        m_bulletMesh->setRotation( metaio::Rotation( metaio::Vector4d(outputQuat.x, outputQuat.y, outputQuat.z , outputQuat.w) ) );
    }

};

class BulletManager
{

public:

    metaio::IMetaioSDKIOS*	m_metaioSDK;
    std::vector< Bullet * > bullets;
    
	// wybuch na ziemi
    struct Explode
    {
//        Texture * texture;
//        Texture * textureExp;
//        Texture * textureExpGround;
//        
//        glFastMesh *explosionFirst;
//        glFastMesh *explosionSecond;
        
        float Pos[ 3 ];
        float Acc[ 3 ];
        float Time;
        float alpha;
        
        Explode() {
            Time = 0.0f;
            alpha = 1.0f;
//            textureExpGround = new Texture( "mesh_fx-ground-explosion-01" );
//            textureExp = new Texture( "mesh_fx-explosion01" );
//            texture = new Texture( "Kaboom" );
//            
//            explosionFirst = MeshManager->GetMesh( "fx_ground-explosion-b", "fx_ground-explosion-b");
//            explosionSecond = MeshManager->GetMesh( "fx_explosion-spherical-c", "fx_explosion-spherical-c");
        }
        
        
        ~Explode() {

        }
        
        // - - - - - - - - - -- -- -

		bool Draw()
        {
            return false;
        }

        // - - - - - - - - - -- -- -

		// moment impaktu pocisku z ziemi¹
        void Kaboom()
        {
            
            Time += globalDT * 5.0;

            if( Time < 3.0 )
            {
                alpha = (3.0f - Time) / 3.0f;
                
//                textureExpGround->Bind();
//                
//                explosionFirst->UserMatrix.t = xVec3(Pos);
//                explosionFirst->UserMatrix.t.y += 1.5;
//                
//                explosionFirst->UserMatrix.M.rotY(-(Time*0.5));
//                
//                explosionFirst->ScaleX = 0.1 * 2.0;
//                explosionFirst->ScaleZ = 0.1 * 2.0;
//                explosionFirst->ScaleY = (0.1 * (1.1 - MIN(Time, 1.0))) * 2.0;
//                
//                explosionFirst->Draw();
                

                
                if( Time < 1.0f )
                {
//                    textureExp->Bind();
//                    
//                    explosionSecond->UserMatrix.t = xVec3(Pos);
//                    explosionSecond->UserMatrix.M.id();
//                    explosionSecond->ScaleY = (0.05 + 0.1 * (Time / 1.0));
//                    explosionSecond->ScaleX = 0.005;
//                    explosionSecond->ScaleZ = 0.005;
//                    
//                    explosionSecond->Draw();
                }
                
                
            }
            
        }

    };

    std::vector< Explode * > exp;

	// renderuj wszystkie kratery na ziemi
    void DrawExplodes()
    {
        for( int i = 0; i < exp. size(); )
            if( exp[ i ] -> Draw() )
            {

                delete exp[ i ];
                exp . erase( exp . begin() + i );

            }
            else

                ++i;

    }
    
    void RemoveAllObjects(){
        for( int i = 0; i < exp. size(); i++) {
            delete exp[ i ];
        }
        
        exp.clear();
        
        for( int i = 0; i < bullets . size(); i++) {
                delete bullets[ i ];
        }
        
        bullets.clear();
    }

	// rendruj efekt uderzenia w ziemie - rozb³yski
    void DrawClouds()
    {
        for( int i = 0; i < exp. size(); ++i )
            exp[ i ] -> Kaboom();
    }

	// symulacja wszytskich pocisków
    void Simulate()
    {

        for( int i = 0; i < bullets . size(); )
            if( bullets[ i ] -> Simulate() )
            {

                Explode * e = new Explode();
                e->Time = 0.0f;

//                memcpy( e -> Pos , bullets[ i ] -> Pos , 12 );
//                memcpy( e -> Acc , bullets[ i ] -> Acc , 12 );
                
                SoundManager -> GetSound( "kaboom" ) -> PlayAt( xVec3(e -> Pos) );

                exp . push_back( e );

                delete bullets[ i ];
                bullets . erase( bullets . begin() + i );

            }
            else

                ++i;

    }

	// renderowanie pocisków
    void Render()
    {
        for( int i = 0; i < bullets . size(); ++i )
            bullets[ i ] -> Render();
    }

	// dodaje nowy pocisk do managera
    void AddBullet( Bullet * b )
    {

        bullets . push_back( b );

    }

};

extern BulletManager Bullets;

#endif

