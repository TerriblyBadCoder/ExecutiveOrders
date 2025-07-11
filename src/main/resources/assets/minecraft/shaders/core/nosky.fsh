#version 150

#moj_import <fog.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;
uniform float STime;
uniform float Offset;
in float vertexDistance;
in vec4 vertexColor;
in vec4 lightMapColor;
in vec4 overlayColor;
in vec2 texCoord0;

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
vec2 rotate(vec2 v, float a) {
    float s = sin(a);
    float c = cos(a);
    mat2 m = mat2(c, s, -s, c);
    return m * v;
}
out vec4 fragColor;

void main() {
    vec4 color = texture(Sampler0, texCoord0);
    vec2 mosaicInSize = vec2(128,128);
    if(Offset>15){
        mosaicInSize = vec2(48,48);
    }
    vec2 texCopy =texCoord0- fract(texCoord0*mosaicInSize)/mosaicInSize;
    vec2 notCoord = texCopy-vec2(0.5,0.5);
    vec2 notCoord2 = notCoord;
    notCoord = normalize(notCoord)*vec2(1,0.2);
    notCoord = rotate(notCoord,STime/30);
    float texY = abs(texCopy.y-0.5)*4;
    float texX = abs(texCopy.x-0.5)*4;
    float noise = -cnoise(vec3(notCoord.x*3,notCoord.y*3+STime/20+Offset*20,STime/10+Offset*20))/1.6+pow(texX*texX+texY*texY,0.5)*0.6;
    notCoord = rotate(notCoord,-STime/5+pow(notCoord2.x*notCoord2.x+notCoord2.y*notCoord2.y,0.5)*2);
    float noiser = abs(cnoise(vec3(notCoord.x*4+3,notCoord.y*4+Offset*20,Offset*20))*2)-pow(texX*texX+texY*texY,2)*0.15;
    float noise2 = clamp(cnoise(vec3(STime/300+Offset))+1,0.9,3);
    noise2 *= noise2;

    noise*=noise2;
    noiser/=noise2;
    noiser*=pow(texX*texX+texY*texY,0.5)*1.4;
    color.rgb = vec3(0.5f,0.5f,0.5f);
    if(noise>0.1){
        float alpha = (0.1-noise)*20;
        color.a *= alpha-fract(alpha*4)/4;
    }
    if(noise>0.15){
        color.a = 0.0f;
    }
    if(noise>0.75&&noise<0.85){
        float alpha = (noise-0.75)*5;
        color.a = alpha-fract(alpha*4)/4;
        color.rgb =vec3(1f,0.02f,0.02f);
    }
    if(noise2>1.5){
        color.a *= clamp((1.7-noise2)*5,0,1);
    }


    if(noiser>0.2 && color.a < 0.5){
        color.a = clamp((1.7-noise2)*5,0,1)*(clamp((noiser-0.2)*10,0,1));

    }
    else  if (color.a < 0.1){
        discard;
    }
    color.a *= vertexColor.a;


    fragColor = color;


}
