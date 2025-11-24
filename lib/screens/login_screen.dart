// lib/screens/login_screen.dart
import 'package:flutter/material.dart';         
// 💡 تم التصحيح: تغيير اسم المشروع إلى my_test_app                                             
import 'package:my_test_app/widgets/login_form_widget.dart';                                    
// import 'package:my_test_app/helpers/auth_service.dart'; // 🛠️ تم إزالة الاستيراد غير المستخدم 
// 💡 تم التصحيح: إضافة استيراد TapGestureRecognizer                                            
import 'package:flutter/gestures.dart';                                                         

class LoginScreen extends StatelessWidget {       
  const LoginScreen({super.key});                                                                 

  // ⭐️⭐️ تم التصحيح: تغيير مسار الشاشة من '/' إلى '/login' ⭐️⭐️
  static const String routeName = '/login';                                                            
  
  @override                                       
  Widget build(BuildContext context) {              
    // استخدم Scaffold لتوفير الهيكل الأساسي للشاشة                                                 
    return Scaffold(                                  
      body: Directionality(                             
        textDirection: TextDirection.rtl, // تحديد اتجاه النص من اليمين لليسار                          
        child: SingleChildScrollView(                     
          child: Container(                                 
            constraints: BoxConstraints(                      
              minHeight: MediaQuery.of(context).size.height,                                                
            ),                                              
            decoration: const BoxDecoration(                  
              gradient: LinearGradient(                         
                begin: Alignment.topLeft,                       
                end: Alignment.bottomRight,                     
                colors: [Color(0xFFf5f7fa), Color(0xFFc3cfe2)],                                               
              ),                                            
            ),                                              
            child: Center(                                    
              child: Container(                                 
                constraints: const BoxConstraints(maxWidth: 650),                                               
                margin: const EdgeInsets.all(10),                                                               
                decoration: BoxDecoration(                        
                  color: Colors.white,                            
                  borderRadius: BorderRadius.circular(20),                                                        
                  boxShadow: [                                      
                    BoxShadow(                                        
                      // 🛠️ تم استبدال withOpacity بقيمة ARGB ثابتة (0x14 = 0.08 * 255)                                
                      color: const Color(0x14000000),                                                                 
                      spreadRadius: 0,                                
                      blurRadius: 25,                                 
                      offset: const Offset(0, 8),                                                                   
                    ),                                            
                  ],                                            
                ),                                              
                child: Row(                                       
                  children: <Widget>[                               
                    // ⭐️ الجزء الجانبي (Banner) - يختفي في الشاشات الصغيرة                                         
                    if (MediaQuery.of(context).size.width > 900)                                                      
                      const Expanded(                                   
                        flex: 1,                                        
                        child: _BannerWidget(),                       
                      ),                                                                                            
                    // ⭐️ جزء نموذج تسجيل الدخول                    
                    Expanded(                                         
                      flex: 1,                                        
                      child: Padding(                                   
                        padding: const EdgeInsets.all(30.0),                                                            
                        child: Column(                                    
                          mainAxisAlignment: MainAxisAlignment.center,                                                    
                          children: <Widget>[                               
                            const Text(                                       
                              'تسجيل الدخول إلى حسابك',                                                                       
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),                                  
                            ),                                              
                            const SizedBox(height: 20),                                                                                                                     
                            // 💡 استدعاء الـ Widget المساعد الذي يحتوي على النموذج 💡                                      
                            const LoginFormWidget(),                                                                                                                        
                            const SizedBox(height: 20),                                                                                                                     
                            const Divider(),                                // ⭐️ الجزء السفلي                              
                            const _FooterWidget(),                                                                        
                          ],                                            
                        ),                                            
                      ),                                            
                    ),                                            
                  ],                                            
                ),                                            
              ),                                            
            ),                                            
          ),                                            
        ),                                            
      ),                                            
    );                                            
  }                                             
}                                                                                               

// ----------------------------------------------------                                         
// مكونات مساعدة خاصة بـ LoginScreen            
// ----------------------------------------------------                                                                                         
// المكون الجانبي (Banner)                      
class _BannerWidget extends StatelessWidget {     
  const _BannerWidget();                                                                          

  @override                                       
  Widget build(BuildContext context) {              
    return Container(                                 
      padding: const EdgeInsets.all(20),              
      decoration: const BoxDecoration(                  
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
        gradient: LinearGradient(                         
          begin: Alignment.topLeft,                       
          end: Alignment.bottomRight,                     
          colors: [Color(0xFF2d9e68), Color(0xFF43b97f)], // var(--button-gradient)                     
        ),                                            
      ),                                              
      child: const Column(                              
        mainAxisAlignment: MainAxisAlignment.center,                                                    
        children: <Widget>[                               
          // Logo Circle                                  
          CircleAvatar(                                     
            radius: 45,                                     
            backgroundColor: Colors.white,                  
            child: Image(                                     
              image: AssetImage('assets/images/logo2.png'), // يجب إضافة الصورة إلى assets                    
              width: 70,                                      
              height: 70,                                   
            ),                                            
          ),
          SizedBox(height: 18),                           
          Text(                                             
            'مرحبًا بك في أسواق أكسب',                       
            style: TextStyle(                                 
              fontSize: 27,                                   
              fontWeight: FontWeight.w700,                    
              color: Colors.white,                          
            ),                                            
          ),                                              
          SizedBox(height: 6),                            
          Padding(                                          
            padding: EdgeInsets.symmetric(horizontal: 10),                                                  
            child: Text(                                      
              'متجر إلكتروني متكامل يلبي كل احتياجاتك',                                                       
              textAlign: TextAlign.center,                    
              style: TextStyle(                                 
                fontSize: 14,                                   
                color: Colors.white70,                          
                height: 1.3,                                  
              ),                                            
            ),                                            
          ),                                            
        ],                                            
      ),                                            
    );                                            
  }                                             
}                                                                                               

// المكون السفلي (Footer)                       
class _FooterWidget extends StatelessWidget {     
  const _FooterWidget();                                                                          

  @override                                       
  Widget build(BuildContext context) {              
    return Text.rich(                                 
      TextSpan(                                         
        text: 'ليس لديك حساب؟ ',                        
        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),                                    
        children: <TextSpan>[                             
          TextSpan(
            text: 'إنشاء حساب',                             
            style: TextStyle(                                 
              color: Theme.of(context).primaryColor,                                                          
              fontWeight: FontWeight.w500,                    
              decoration: TextDecoration.underline,
            ),                                              
            // الآن TapGestureRecognizer() مُعرَّف بفضل الاستيراد الجديد                                       
            recognizer: TapGestureRecognizer()                
              ..onTap = () {                                    
                // 💡 التوجيه إلى مسار التسجيل (مسار مسمّى آخر)
                Navigator.of(context).pushNamed('/register'); 
              },                                          
          ),                                            
        ],                                            
      ),                                              
      textAlign: TextAlign.center,                  
    );
  }                                             
}
