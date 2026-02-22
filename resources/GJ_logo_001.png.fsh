#ifdef GL_ES
precision mediump float;
#endif

varying vec4 v_fragmentColor;
varying vec2 v_texCoord;
uniform sampler2D CC_Texture0;

uniform float u_time;
uniform float u_pulse1;
uniform float u_pulse3;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 ip = floor(p);
    vec2 fp = fract(p);
    fp = fp * fp * (3.0 - 2.0 * fp);
    return mix(
        mix(rand(ip), rand(ip + vec2(1.0, 0.0)), fp.x),
        mix(rand(ip + vec2(0.0, 1.0)), rand(ip + vec2(1.0, 1.0)), fp.x),
        fp.y
    );
}

// Экстремальная резкость
vec4 extremeSharpen(sampler2D tex, vec2 uv, float intensity) {
    vec2 texelSize = vec2(1.0 / 512.0);
    
    vec4 c = texture2D(tex, uv);
    vec4 n = texture2D(tex, uv + vec2(0.0, texelSize.y));
    vec4 s = texture2D(tex, uv - vec2(0.0, texelSize.y));
    vec4 e = texture2D(tex, uv + vec2(texelSize.x, 0.0));
    vec4 w = texture2D(tex, uv - vec2(texelSize.x, 0.0));
    
    vec4 laplacian = -n - s - e - w + 4.0 * c;
    return c + laplacian * intensity;
}

void main() {
    vec2 uv = v_texCoord;
    float t = u_time;
    
    // Блочная пикселизация в рандомных местах
    vec2 blockCoord = floor(uv * 20.0);
    float blockRand = rand(blockCoord + floor(t * 3.0));
    
    vec2 glitchUV = uv;
    
    // Горизонтальные глитч-бары
    float barHeight = 0.05;
    float barPos = floor(uv.y / barHeight);
    float barGlitch = step(0.93, rand(vec2(barPos, floor(t * 8.0))));
    
    if (barGlitch > 0.5) {
        glitchUV.x += (rand(vec2(barPos, t)) - 0.5) * 0.15 * u_pulse1;
    }
    
    // Вертикальные разрывы
    float verticalSlice = floor(uv.x * 15.0);
    float sliceGlitch = step(0.95, rand(vec2(verticalSlice, floor(t * 5.0))));
    
    if (sliceGlitch > 0.5) {
        glitchUV.y += (rand(vec2(verticalSlice, t * 2.0)) - 0.5) * 0.1;
    }
    
    // Зоны с экстремальной резкостью
    float sharpnessMap = noise(uv * 3.0 + vec2(t * 0.2, 0.0));
    float sharpIntensity = step(0.6, sharpnessMap) * (2.0 + u_pulse3 * 3.0);
    
    // RGB смещение с вращением
    float angle = t + noise(uv * 0.0) * 6.28;
    vec2 rgbOffset1 = vec2(cos(angle), sin(angle)) * 0.005;
    vec2 rgbOffset2 = vec2(cos(angle + 2.09), sin(angle + 2.09)) * 0.005;
    vec2 rgbOffset3 = vec2(cos(angle + 4.18), sin(angle + 4.18)) * 0.005;
    
    vec4 colorR = extremeSharpen(CC_Texture0, glitchUV + rgbOffset1, sharpIntensity);
    vec4 colorG = extremeSharpen(CC_Texture0, glitchUV + rgbOffset2, sharpIntensity);
    vec4 colorB = extremeSharpen(CC_Texture0, glitchUV + rgbOffset3, sharpIntensity);
    
    vec4 color = vec4(colorR.r, colorG.g, colorB.b, colorG.a);
    
    // Разрушение краёв - эрозия
    float edgeMask = texture2D(CC_Texture0, uv).a;
    float erosion = noise(uv * 50.0 + t);
    
    // Определяем край
    float edge = abs(texture2D(CC_Texture0, uv + vec2(0.02, 0.0)).a - 
                     texture2D(CC_Texture0, uv - vec2(0.02, 0.0)).a);
    edge += abs(texture2D(CC_Texture0, uv + vec2(0.0, 0.02)).a - 
                texture2D(CC_Texture0, uv - vec2(0.0, 0.02)).a);
    
    if (edge > 0.05) {
        // На краю - применяем эрозию
        float corruptionChance = noise(uv * 80.0 + t * 2.0);
        if (corruptionChance > 0.7) {
            color.a *= corruptionChance * (0.5 + u_pulse1 * 0.5);
            // Цветные артефакты на краях
            color.rgb += vec3(
                rand(uv + t) * 0.3,
                rand(uv + t + 0.1) * 0.3,
                rand(uv + t + 0.2) * 0.3
            );
        }
    }
    
    // Блочные артефакты
    if (blockRand > 0.92) {
        vec2 blockUV = blockCoord / 20.0;
        vec4 blockColor = texture2D(CC_Texture0, blockUV);
        color = mix(color, blockColor, 0.7);
    }
    
    // Цифровой шум на ярких участках
    if (color.a > 0.5) {
        float digitalNoise = rand(uv * 200.0 + t * 10.0);
        if (digitalNoise > 0.97) {
            color.rgb = vec3(digitalNoise);
            color.a = 1.0;
        }
    }
    
    gl_FragColor = color * v_fragmentColor;
}