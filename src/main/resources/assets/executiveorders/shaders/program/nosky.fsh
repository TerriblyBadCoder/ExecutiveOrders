#version 150


uniform sampler2D DiffuseSampler;
uniform sampler2D DepthSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D SkySampler;
uniform sampler2D OutlineSampler;
uniform sampler2D OutlineParSampler;
in vec2 texCoord;
in vec2 oneTexel;
uniform vec2 InSize;
uniform float GameTime;
uniform float _FOV;
uniform vec3 PosOfYou;
uniform vec2 RotOfYou;
uniform float Strength;
out vec4 fragColor;
const float near = 0.01;
const float far = 100.0;

vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}
vec3 fade(vec3 t) {return t*t*t*(t*(t*6.0-15.0)+10.0);}
vec2 rotate(vec2 v, float a) {
    float s = sin(a);
    float c = cos(a);
    mat2 m = mat2(c, s, -s, c);
    return m * v;
}
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
void main() {
    bool shouldfract = false;
    vec2 notCoord = texCoord;
    float clamped = clamp(RotOfYou.y,0.05,1);
    float scaleoff = 0;
    if(RotOfYou.y<0){
        scaleoff = -RotOfYou.y;
    }
    vec2 texCoorded = texCoord;
    if(scaleoff>0)
    texCoorded = texCoord-(fract(texCoord*32/scaleoff)/16)*scaleoff;
    notCoord = texCoorded-vec2(0.5,0.5);
    vec2 notCoord2 = notCoord;
    float y = 1-clamp(PosOfYou.y/16,0,1);
    vec2 texCopy = texCoorded - fract(texCoorded*InSize/16)/(InSize)*16;
    float center=pow((1-abs(texCopy.y-0.5)*2)*(1-abs(texCopy.x-0.5)*2),0.5)+abs(cnoise(vec3((texCoorded.x - fract(texCoorded.x*InSize.x/16)/InSize.x*16)*12,(texCoorded.y - fract(texCoorded.y*InSize.y/16)/InSize.y*16)*4,GameTime*800)))/1.2;
    center -=fract(center*8)/8;
    float center2=pow((1-abs(texCopy.y-0.5)*2)*(1-abs(texCopy.x-0.5)*2),0.5)+abs(cnoise(vec3((texCoorded.x - fract(texCoorded.x*InSize.x/16)/InSize.x*16)*4,(texCoorded.y - fract(texCoorded.y*InSize.y/16)/InSize.y*16)*12,GameTime*800)))/1.2;
    center2 -=fract(center*8)/8;
    y*=Strength;
    if(PosOfYou.y<16){

        vec2 mosaicInSize = InSize/16;

        notCoord2 = notCoord2-fract(notCoord2*mosaicInSize)/mosaicInSize;
        notCoord2.x += sin((notCoord2.y+0.5)*32+GameTime*4000+(notCoord2.x+0.5)*2)*y*length(notCoord2)*2;
    }
    notCoord+=vec2(0.5,0.5);
    float depth = LinearizeDepth(texture(DepthSampler, notCoord).r);
    vec3 distVec = (vec3(1., (2.*notCoord - 1.) * vec2(InSize.x/InSize.y,1.) * tan(radians(_FOV / 2.))) * depth);
    float distance = length(distVec);
    float yOff = distance*Strength + cnoise(distVec+PosOfYou/40)/2*Strength;
    yOff = clamp(yOff-4*clamped,0,400);
    vec2 mosaicInSize = InSize / 4;
    vec4 color = texture(DiffuseSampler,notCoord);
    fragColor = color;

    if(((texture(OutlineSampler,notCoord).a>0.0f && distance>(10+(1-clamped)*20))||texture(OutlineParSampler,notCoord).a>0.0)&&texture(DiffuseDepthSampler, notCoord).r>0.98){
        float alphamain =texture(OutlineSampler,notCoord).a* clamp((distance-10)/4,0,1f);
        float alpha =max(alphamain,texture(OutlineParSampler,notCoord).a);
        if(texture(OutlineSampler,notCoord).r>0.8f && alpha ==alphamain){
            vec3 hsv = rgb2hsv(texture(SkySampler,notCoord).rgb);
            hsv.x = fract(notCoord.y*20);
            hsv.z *= clamped;
            hsv = hsv2rgb(hsv);
            fragColor = vec4(hsv,1)*alpha+color*(1-alpha);
        }
        else if(texture(OutlineSampler,notCoord).r*texture(OutlineSampler,notCoord).b < 0.01f && alpha ==alphamain){
            fragColor = vec4(0,0,0,1)*alpha+color*(1-alpha);
        }
        else{
            fragColor = texture(SkySampler,notCoord)*alpha+color*(1-alpha);
        }
    }
    else{
        if(yOff>1 && yOff<40 && texture(DiffuseDepthSampler, texCoorded).r>0.98){
            vec3 tex = color.rgb;
            tex = rgb2hsv(tex);
            float redder = clamp((yOff-1)/5,0,1);
            tex = hsv2rgb(vec3(cnoise(distVec/40+PosOfYou/1600+vec3(GameTime*5))/10*clamped,tex.y,tex.z*(clamped/1.5+0.25)))*redder+ hsv2rgb(tex)*(1-redder);

            fragColor = vec4(tex,color.a);

        }
        else{
            fragColor = color;
        }
    }
    if(length(notCoord2)*2>1.8-y/2&&PosOfYou.y<16){
        float alph2a = clamp((length(notCoord2)*2-1.8+y/2)*5,0,1);
        fragColor = texture(SkySampler,notCoord)*alph2a+fragColor*(1-alph2a);
    }
    fragColor.yz*=(clamp(center+0.5+clamped,0,1));

    fragColor*=(clamp(center2+0.6+clamped,0,1));



}