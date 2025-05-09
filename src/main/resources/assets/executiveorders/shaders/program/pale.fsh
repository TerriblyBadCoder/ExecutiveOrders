#version 150
uniform sampler2D DiffuseSampler;
uniform sampler2D DepthSampler;
uniform sampler2D SculkSampler;
uniform sampler2D ActualSculkSampler;
uniform sampler2D SculkSamplerDepth;
uniform sampler2D DiffuseDepthSampler;
in vec2 texCoord;
in vec2 oneTexel;

uniform vec2 InSize;
uniform float GameTime;
uniform float _FOV;
uniform vec2 CamRot;
uniform float Fade;
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}
vec3 fade(vec3 t) {return t*t*t*(t*(t*6.0-15.0)+10.0);}
float cnoise(vec3 P){
    vec3 Pi0 = floor(P); // Integer part for indexing
    vec3 Pi1 = Pi0 + vec3(1.0); // Integer part + 1
    Pi0 = mod(Pi0, 289.0);
    Pi1 = mod(Pi1, 289.0);
    vec3 Pf0 = fract(P); // Fractional part for interpolation
    vec3 Pf1 = Pf0 - vec3(1.0); // Fractional part - 1.0
    vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
    vec4 iy = vec4(Pi0.yy, Pi1.yy);
    vec4 iz0 = Pi0.zzzz;
    vec4 iz1 = Pi1.zzzz;

    vec4 ixy = permute(permute(ix) + iy);
    vec4 ixy0 = permute(ixy + iz0);
    vec4 ixy1 = permute(ixy + iz1);

    vec4 gx0 = ixy0 / 7.0;
    vec4 gy0 = fract(floor(gx0) / 7.0) - 0.5;
    gx0 = fract(gx0);
    vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
    vec4 sz0 = step(gz0, vec4(0.0));
    gx0 -= sz0 * (step(0.0, gx0) - 0.5);
    gy0 -= sz0 * (step(0.0, gy0) - 0.5);

    vec4 gx1 = ixy1 / 7.0;
    vec4 gy1 = fract(floor(gx1) / 7.0) - 0.5;
    gx1 = fract(gx1);
    vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
    vec4 sz1 = step(gz1, vec4(0.0));
    gx1 -= sz1 * (step(0.0, gx1) - 0.5);
    gy1 -= sz1 * (step(0.0, gy1) - 0.5);

    vec3 g000 = vec3(gx0.x,gy0.x,gz0.x);
    vec3 g100 = vec3(gx0.y,gy0.y,gz0.y);
    vec3 g010 = vec3(gx0.z,gy0.z,gz0.z);
    vec3 g110 = vec3(gx0.w,gy0.w,gz0.w);
    vec3 g001 = vec3(gx1.x,gy1.x,gz1.x);
    vec3 g101 = vec3(gx1.y,gy1.y,gz1.y);
    vec3 g011 = vec3(gx1.z,gy1.z,gz1.z);
    vec3 g111 = vec3(gx1.w,gy1.w,gz1.w);

    vec4 norm0 = taylorInvSqrt(vec4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
    g000 *= norm0.x;
    g010 *= norm0.y;
    g100 *= norm0.z;
    g110 *= norm0.w;
    vec4 norm1 = taylorInvSqrt(vec4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
    g001 *= norm1.x;
    g011 *= norm1.y;
    g101 *= norm1.z;
    g111 *= norm1.w;

    float n000 = dot(g000, Pf0);
    float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
    float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
    float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
    float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
    float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
    float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
    float n111 = dot(g111, Pf1);

    vec3 fade_xyz = fade(Pf0);
    vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111), fade_xyz.z);
    vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
    float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x);
    return 2.2 * n_xyz;
}
float near = 0.1;
float far = 100.0;
float LinearizeDepth(float depth)
{
    float z = depth * 2.0f - 1.0f;
    return (near * far) / (far + near - z * (far - near));
}
vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
vec2 rotate(vec2 v, float a) {
    float s = sin(a);
    float c = cos(a);
    mat2 m = mat2(c, s, -s, c);
    return m * v;
}
out vec4 fragColor;

void main() {
    vec2 mosaicInSize = InSize /8;
    vec2 texCopy =texCoord- fract(texCoord*mosaicInSize)/mosaicInSize;
    vec2 texCopier = vec2(texCopy.x+sin(texCopy.y*180+texCoord.x*40+GameTime*30000)/40*CamRot.y,texCopy.y+sin(texCopy.x*180+texCoord.y*40+GameTime*30000)/400*CamRot.y);
    texCopy = texCopier;
    float texY = abs(texCopy.y-0.5)*2;
    float texX = abs(texCopy.x-0.5)*2;
    vec2 dir2 = vec2(0.5,0.5)-texCopy;

    float dirCopy = (pow(dir2.x*dir2.x+dir2.y*dir2.y,0.5))/50+GameTime*4;

    vec2 dir = vec2(0.5,0.5)-texCopy;
    dir = normalize(dir);
    dir = rotate(dir,dirCopy);
    float noisy2 = (cnoise(vec3(texCopy.x*10+GameTime*200+1,texCopy.y*10+GameTime*200+1,GameTime*400+1))+1)/2-1.5+texY+texX;
    noisy2*= Fade/2;


    float noisy = cnoise(vec3(dir.x*5+GameTime*20,dir.y*5+GameTime*20,GameTime*400))*0.5-0.6+pow(texY*texY+texX*texX,0.5);
    noisy *= clamp(Fade,0,0.6)*1.6;

    float depth = LinearizeDepth(texture(DepthSampler, texCopy).r);
    float distance = length(vec3(1., (2.*texCoord - 1.) * vec2(InSize.x/InSize.y,1.) * tan(radians(_FOV / 2.))) * depth);

    float depth2 = LinearizeDepth(texture(DepthSampler, texCopy).r);

    float distance2 = length(vec3(1., (2.*texCopy - 1.) * vec2(InSize.x/InSize.y,1.) * tan(radians(_FOV / 2.))) * depth2);
    distance = clamp(distance,0,192)/6;
    vec2 mosaicInDistSize = InSize *4/pow(distance,0.5);
    vec2 fractPix = fract((texCoord+sin(GameTime*30000)/3) * mosaicInDistSize) / mosaicInDistSize;
    vec4 baseTexel = texture(DiffuseSampler, texCoord+cos(GameTime*3000+texCoord*distance*90)/10000*distance*Fade+sin(texCoord*distance*90)/50000*distance*Fade - fractPix);
    vec4 baseCopy = texture(DiffuseSampler,texCoord+cos(GameTime*3000+texCoord*distance*90)/10000*distance*Fade+sin(texCoord*distance*90)/5000*distance*Fade);
    vec3 hsvTexel = rgb2hsv(baseTexel.rgb);
    float offset =  0.5-(min(abs(0.55 - hsvTexel.x),abs(hsvTexel.x+0.45))*2);
    hsvTexel.x = 0.6;

    hsvTexel.z = pow(hsvTexel.z*0.9,1.6);
    baseTexel.rgb = hsv2rgb(hsvTexel);
    baseTexel.b = pow(baseTexel.b,0.7);
    baseTexel.a = 1.0;
    noisy2/=2;
    noisy2-=fract(noisy2*8)/8;
    vec4 frag1 = texture(SculkSampler,texCoord);
    vec4 frag2 = texture(SculkSampler,texCoord+cos(GameTime*3000+texCoord.y*40)/100*Fade+sin(texCoord.x*40)/50*Fade);
    noisy2 = clamp(noisy2,0,1);
    float noisy3 = noisy;
    float difDepth = texture(DiffuseDepthSampler, texCoord).r;
    if((1-CamRot.y/0.65)>0.1)
        noisy = max(noisy,clamp(distance2/2*Fade/0.7-3,0,0.7));
    if(noisy3<noisy){
        if(noisy>0.5){
            noisy = 0.5 + clamp(distance2/32-0.2,0,0.2);
        }

        noisy*=(1-CamRot.y/0.65);

        if(distance2>40||difDepth<0.98){
            noisy = noisy3;
        }
    }
    if(noisy>0.1 && CamRot.y>0.05){
        baseCopy = texture(DiffuseSampler,texCopy);
    }
    vec4 futFragColor = baseTexel*Fade+baseCopy*(1-Fade)-noisy2;


    if(distance>0.8&&difDepth>0.98){
        distance = clamp((distance-0.8)/2,0,1);
        distance*=Fade/0.8;
        futFragColor =futFragColor*(1-distance)+vec4(0,0,0,1)*distance;
    }
    if(CamRot.x>0 && CamRot.y>0.45 ){
        float tempy = (CamRot.y-0.45)/0.2;
        noisy *= (90-CamRot.x)/90*tempy;
    }

        if(noisy<0.5){

            if(noisy>=0.35){
                float howmuch = 1-clamp((0.5-noisy)/0.15,0,1);
                howmuch-=fract(howmuch*3)/3;
                futFragColor =  vec4(0.4,0.55,0.8,1)*howmuch*(vec4(0.65-CamRot.y,0.65-CamRot.y,0.65-CamRot.y+0.01,1))+futFragColor*(1-howmuch);
                if(frag1.b!=0){
                    futFragColor.rgb = mix(futFragColor.rgb,frag1.rgb/1.5,frag1.a/1.5);
                }
                fragColor =futFragColor;
            }
            else{

                if(frag1.b!=0 &&difDepth>0.98){
                    futFragColor.rgb = mix(futFragColor.rgb,frag1.rgb/2,frag1.a/2);
                }

                fragColor = futFragColor;
            }

        }
        else{
            float multTex = 0;
            float mixTex = 1;
            if(noisy3<noisy){
                multTex = distance2/3-fract((distance2/3)*4)/4;
                mixTex = clamp((distance2/20*Fade/0.7),0,1);
            }

            float GameTime2 = GameTime-fract(GameTime*(48000/(1+multTex/5)))/(48000/(1+multTex/5));
            float tex1 = texCoord.x*3*(1+multTex/6)+GameTime2*50*(1+multTex*0.2)+cos(texCoord.x*3*(1+multTex/2)+GameTime2*300*(1+multTex/5))/30;
            float tex2= texCoord.y*3*(1+multTex/4)+GameTime2*200+sin(texCoord.y*3*(1+multTex)+GameTime2*300*(1+multTex/5))/30;
            float tex3 = texCoord.x*3*(1+multTex/12)+GameTime2*400*(1+multTex*0.2)+texCoord.y/2;
            float tex4= texCoord.y*3*(1+multTex/16)+GameTime2*100*(1+multTex*0.2);
            frag1 =texture(ActualSculkSampler,vec2(fract(tex1-fract(tex1*64)/64),fract(tex2-fract(tex2*64)/64)))*0.3
            +texture(ActualSculkSampler,vec2(fract(tex3-fract(tex3*64)/64),fract(tex4-fract(tex4*64)/64)))*0.7;
            frag1*=vec4(0.6,0.8,1,1)*clamp(((noisy-0.45)*7-0.5),0,1);
            if(length(texture(SculkSampler,texCoord).xyz)>0.33){
                frag1 = vec4(0.4,0.55,0.8,1);
            }
            if(noisy3>=noisy){
                fragColor = frag1;
            }
            else{
                fragColor = mixTex*frag1+(1-mixTex)*futFragColor;
            }


        }

}
