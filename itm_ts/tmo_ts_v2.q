import "Quasar.Video.dll"
import "Quasar.UI.dll"
import "Quasar.Runtime.dll"
import "Sim2HDR.dll"
import "Quasar.UI.dll"
import "immorphology.q"
import "fastguidedfilter.q"
import "inttypes.q"
import "system.q"
import "colortransform.q"

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Toe, shoulder Tonemapper                                             %
% http://gpuopen.com/wp-content/uploads/2016/03/GdcVdrLottes.pdf       %
% {a:contrast,d:shoulder} shapes curve                                     %
% {b,c} anchors curve                                                  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%// improved crosstalk –maintaining saturationfloat tonemappedMaximum; // 
%max(color.r, color.g, color.b)float3 ratio;.
%// color / tonemappedMaximumfloat crosstalk; 
%// controls amount of channel crosstalkfloat saturation; 
%// full tonal range saturation controlfloat crossSaturation; 
%// crosstalk saturation
%// wrap crosstalk in transformratio = pow(ratio, saturation / crossSaturation);
%ratio = lerp(ratio, white, pow(tonemappedMaximum, crosstalk));
%ratio = pow(ratio, crossSaturation);// final colorcolor = ratio * tonemappedMaximum;


%Update B and C values
function [] = updateBC(t:object)
    t.b= (-t.midIn^t.a + t.hdrMax^t.a*t.midOut)/(((t.hdrMax^t.a)^t.d-(t.midIn^t.a)^t.d) * t.midOut);
    t.c= ((t.hdrMax^t.a)^t.d*t.midIn^t.a-t.hdrMax^t.a *(t.midIn^t.a)^t.d*t.midOut)/(((t.hdrMax^t.a)^t.d-(t.midIn^t.a)^t.d)*t.midOut)
end

function [y:vec3] = __device__ clamp_values(x:vec3'unchecked,l:scalar,h:scalar)
    y=uninit(size(x))
    for i=0..2
        if x[i]>h
            y[i]=h
        elseif x[i]<l
            y[i]=l  
        else
            y[i]=x[i]
        endif  
    end
end

%Kernel to Apply tmo operator to Separation of Max an RGB ratio in parllel
function [y:cube] = color_grade(x:cube,t:object)
    function []= __kernel__ color_grade_kernel(x:cube'unchecked,y:cube'unchecked,a:scalar,b:scalar,c:scalar,d:scalar,p:scalar,pos:ivec2)
        {!kernel target="gpu"}
        input=x[pos[0],pos[1],0..2];
        
        %Apply Separation of Max an RGB ratio
        peak=max(input);
        ratio=input/peak;
        peak=(peak.^a)./(((peak.^a).^d).*b+c);
        output=peak*ratio;
        %Clamp and peak luminance ratio
        output=p*clamp_values(output,0.0,1.0) %Clamp values
        syncthreads
        y[pos[0],pos[1],0..2]=output;
    end
    y=uninit(size(x))
    parallel_do(size(x,0..1),x,y,t.a,t.b,t.c,t.d,t.peak_luminance_ratio,color_grade_kernel)
end

%Linearize sRGB
function l = sRGB_decode(x) 
    l = (x<=0.04045).*x./12.92 + (((x>0.04045).*x+0.055)/1.055).^2.4;
end  

%Linearize input video using sRGB decode
function y = linearize(x)
    y=sRGB_decode(x./255.0)
end

%Unmake
function [] = unmake_raw_cube(x:cube, y:cube)
    y[:,:,0..2] = x[:,:,[2,1,0]]
end



% 1D Horizontal filter kernel
function [] = __kernel__ pocs_horizontal_run(y : cube'unchecked, _
    x : cube' clamped, r : int, pos : ivec3)
    sum = 0.0
    for m=0..2*r
        sum += x[pos + [0,m-r,0]]
    end
    y[pos] = sum/(2*r+1)
end

% 1D Vertical filter kernel
function [] = __kernel__ pocs_vertical_run(y : cube'unchecked, _
    x : cube' clamped, r : int, high:cube' unchecked, low:cube'unchecked, pos : ivec3)
    sum = 0.0
    for m=0..2*r
        sum += x[pos + [m-r,0,0]]
    end
    y[pos] = min(max(sum/(2*r+1),low[pos]),high[pos])
end

%Apply lut
% writes actual value in y_o, lower bound of quantization limit in low, higher bound in high
function [] = apply_LUT(y:cube'unchecked,y_o:cube'unchecked,low:cube'unchecked,high:cube'unchecked,lut:vec'unchecked,step:'unchecked)
    function [] = __kernel__ apply_LUT_kernel(y_o:cube'unchecked,low:cube'unchecked,high:cube'unchecked,lut:vec'clamped,step:int'unchecked,pos:ivec3)
        index:int = floor(y[pos[0],pos[1],pos[2]])
        y_o[pos[0],pos[1],pos[2]] = lut[index]
        low[pos[0],pos[1],pos[2]] = lut[index]-(lut[index]-lut[index-step])/2
        high[pos[0],pos[1],pos[2]] = lut[index]+(lut[index+step]-lut[index])/2
    end
    parallel_do(size(y),y_o,low,high,lut,step,apply_LUT_kernel)
end

%Linear simple expansion
function [y:cube]=linear_expansion(x:cube'unchecked,max_value:scalar)
    function []= __kernel__ linear_expansion_kernel(x:cube'unchecked,y:cube'unchecked,max_value:scalar,pos:ivec2)
        {!kernel target="gpu"}
        input=x[pos[0],pos[1],0..2];
        y[pos[0],pos[1],0..2]=input*max_value;
    end
    y=uninit(size(x))
    parallel_do(size(x,0..1),x,y,max_value,linear_expansion_kernel) %Size is WxH
end

%Get luminance using HSL color space
function [lum] = __device__ getluminance(c : vec3)
    cmax = max(c)
    cmin = min(c)
    lum = 0.5 * (cmin + cmax)  % lightness
end

%Get luminance using HSL color space
function [lum:mat] = getLumaImage(image : cube)
    function [] = __kernel__ getLuma_kernel(x:cube'unchecked,y:mat'unchecked,pos:ivec2)
       cmax = max([x[pos[0],pos[1],0],x[pos[0],pos[1],1],x[pos[0],pos[1],2]])
       cmin = min([x[pos[0],pos[1],0],x[pos[0],pos[1],1],x[pos[0],pos[1],2]])
       y[pos[0],pos[1]] = 0.5 * (cmin + cmax)  % lightness
    end
    lum:mat=uninit(size(image,0..1))
    parallel_do(size(lum),image,lum,getLuma_kernel)   
end

%Get enhance bright mask
function [y:mat]=get_bright_mask(x:cube'unchecked,params:object)
    %Thresholding kernel functions
    function []= __kernel__ thresholding_sat(x:cube'unchecked,y:mat'checked,th:scalar,pos:ivec2)
        luma = getluminance(x[pos[0],pos[1],0..2])
        %At least one channel saturated 
        if(luma > th)
        %if(max(x[pos[0],pos[1],0..2])>0.7 && luma > th)
            y[pos[0],pos[1]] = 1.0;
        else
            y[pos[0],pos[1]] = 0.0
        endif
    end

    function []= __kernel__ thresholding(x:mat'checked,y:mat'unchecked,th:scalar,pos:ivec2)
        if(x[pos[0],pos[1]]>= th)
           y[pos[0],pos[1]] = x[pos[0],pos[1]];
        else
           y[pos[0],pos[1]] = 0.0
        endif
    end

    %Thresholding original image
    y=uninit(size(x,0..1)) 
    parallel_do(size(y),x,y,params.th1,thresholding_sat) %Size is WxH    
    
    %Gaussian filter with static values
    y=gaussian_filter(y,15.0,85)/max(y)
    
    %Thresholding the gaussian image filtered
    parallel_do(size(y),y,y,params.th2,thresholding) %Size is WxH    

    y = fastguidedfilter(getLumaImage(x),y,32, 10^-6);
    y=gaussian_filter(y,5)/max(y)
     
   
end

%Apply bright mask
function [y:cube]=apply_bright_mask(x:cube'unchecked,mask:mat'unchecked, f:scalar)
    function []= __kernel__ linear_get_mask(x:cube'unchecked,y:cube'unchecked,mask:mat'unchecked,f:scalar,pos:ivec2)
        {!kernel target="gpu"}
        if(mask[pos[0],pos[1]]>0)
            y[pos[0],pos[1],:]=x[pos[0],pos[1],:]*(1+mask[pos[0],pos[1]]*f)
        else
            y[pos[0],pos[1],:]=x[pos[0],pos[1],:]; 
        endif
    end
    y=uninit(size(x))
    parallel_do(size(x,0..1),x,y,mask,f,linear_get_mask) %Size is WxH
end

function [] = main()
%    video_file="F:/HDR-SDR+-SDR/SDR/SC - manual grading/AutoWeldingClip.avi"
%    video_file="F:/movie_trailers/dawnoftheplanetoftheapes-tlr2_h1080p.mov"
%    video_file = "F:/more_content/Tomorrowland_2015__Official_Aftermovie.MP4"
%video_file = "E:/tom_convert/SC-manual/BikeSparklersClip.avi"
%    video_file = "F:/movie_trailers/Mad_Max_Fury_Road_2015_Trailer_F4_5.1-1080p-HDTN.mp4"
%    video_file = "F:/more_content/eoft2.MP4"
%    video_file="F:/movie_trailers/Interstellar_2014_trailer_2_5.1-1080p-HDTN.mp4"
%    video_file="F:/movie_trailers/revenant-tlr1_h1080p.mov"
%    video_file="F:/movie_trailers/rogueone-tsr1_h1080p.mov"
%    video_file="F:/movie_trailers/Star_Wars_Episode_VII_The_Force_Awakens_2015_Trailer_B_5.1-1080p-HDTN.mp4"
%    video_file="F:/movie_trailers/The Angry Birds Movie (2016) DVDRip LAT-ZeiZ.mkv"
%    video_file="F:/movie_trailers/thewheel-got-acard_h1080p.mov"

video_file="F:/movie_trailers/sing-trailer-6_h1080p.mov"

%    jef = imread("C:\Users\ipi\Desktop\ishihara_10.jpg")/255
%    h = hdr_imshow((jef.^(2.2))/10,[0,1])
%    y = h.rasterize()
%    frame_pngsave = zeros(size(y))
%    s_height = size(jef,0)
%    frame_pngsave[50..s_height-50-1,0..size(y,1)-10,:] = y[50..s_height-50-1,0..size(y,1)-10,:]
%    y= uint8_to_float(y[size(y,0)-1..-1..0,:,:])
%    imwrite("C:\Users\ipi\Desktop\bla2.png", y)
%    return


    % Output PNG file path
    png_out_folder = "C:/Users/ipi/Videos/"
    png_frame_counter=1;
    png_out_w = 1920
    png_out_h = 1080    
                
    %%%%%%%%%%%%%%%% General Params %%%%%%%%%%%%%%%%
    general_params = object()
    general_params.peak_luminance = 2500
    general_params.peak_luminance_display = 6000
    general_params.peak_luminance_r = general_params.peak_luminance/general_params.peak_luminance_display % 5000 nits maximun on regular 
    general_params.boost_luminance_r = 1-general_params.peak_luminance_r;

    target_bits_per_color = 16.0 %Number of bits
    max_value = 2^target_bits_per_color-1
    sdr_factor = 6;%2.4%10
      
    %%%%%%%%%%%%%%%% Denoising PARAMS %%%%%%%%%%%%%%%
    denoising_method=0
    %NLMS settings- 0
    search_wnd = 2
    half_block_size = 1
    correlated_noise = 0.0
    %Guided filter
    gf_params = object()
    gf_params.r=4.0
    gf_params.epsf=1.1
    gf_params.eps=(gf_params.epsf)^2;
    
    %%%%%%%%%%%%  Color graded PARAMS %%%%%%%%%%%%%%%%
    % Derfault params
    tmo_params = object()
    tmo_params.a:scalar= 1.41 % Contrast
    tmo_params.d:scalar = 2.25  % Shoulder
    tmo_params.midIn:scalar=25000%(0.18^(1/2.2))*(2^16-1);
    tmo_params.midOut:scalar=0.382; %This value could be change dynamically .. TODO
    tmo_params.hdrMax:scalar=max_value %HDR Max value default (in image)
    tmo_params.peak_luminance_ratio:scalar=general_params.peak_luminance_r %HDR Max value default (in image)
    updateBC(tmo_params);
    
    %%%%%%%%%%%% POCS  %%%%%%%%%%%%%%%
    pocs_params = object();
    pocs_params.r_pocs=6
    pocs_params.it=6
    pocs_params.steps=36
        
    %%%%%%%%%%% ENHANCE BRIGHT %%%%%%%%%%%
    eb_params = object()
    eb_params.th1=0.721; %Same as LDR2HDR 
    eb_params.th2=0.115; %Same as LDR2HDR 
    eb_params.f=0.25; 
    
    %%%%%%%%%%%%%%%%%%%% FORM %%%%%%%%%%%%%%%%%%%%%%%
    frm = form("Color grading")
    frm.width = 600
    frm.height = 900
    frm.center()
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    stream = vidopen(video_file) % Opens the specified video file for playing
    %stream.bits_per_color = 8;

    %Variables
    s_width=stream.frame_width
    s_height=stream.frame_height
    
    frame = cube(s_height,s_width,3)
    frame_denoised = cube(s_height,s_width,3)
    frame_expanded = cube(s_height,s_width,3)
    frame_graded = cube(s_height,s_width,3)
    
    frame_bright_mask = mat(s_height,s_width)
   
    frame_l = cube(s_height,s_width,3)
    frame_u = cube(s_height,s_width,3)
    frame_v_buff = cube(s_height,s_width,3)
    frame_dequant = cube(s_height,s_width,3)
    
    frame_pngsave = zeros(png_out_h,png_out_w,3)
    
    frame_show = cube(s_height,s_width,3)

    sz = [s_height,s_width,3]   
    looping = true

    % Sets the frame rate for the imshow function
    sync_framerate(stream.avg_frame_rate) 
    
    % GUI
    frm.add_heading("General parameters")
    cb_moving_line = frm.add_checkbox("Moving line", false)
    cb_side_by_side = frm.add_checkbox("Compare side by side", false)
    cb_no_line = frm.add_checkbox("No line", true)
    cb_record = frm.add_checkbox("Recording", false)
    
    frm.add_heading("Denoising parameters (LDR non-linear space)")
    cb_denoise = frm.add_checkbox("Denoising: ", true)
    slider_denoising_epsf = frm.add_slider("Denoising factor:",gf_params.epsf,0.1,20.0)
 
    frm.add_heading("POCS")
    cb_pocs = frm.add_checkbox("POCS: ", true)
    slider_pocs_steps = frm.add_slider("S:",pocs_params.steps,1,512)
    
    frm.add_heading("Brightness")
    cb_enhance_brightness = frm.add_checkbox("Enhance Brigthness: ", true)
    cb_show_brightness_mask = frm.add_checkbox("Show Mask ", false)
    slider_brightness_th1 = frm.add_slider("th1:",eb_params.th1,0.18,1.0)
    slider_brightness_th2 = frm.add_slider("th2:",eb_params.th2,0.1,1.0)
    slider_brightness_f = frm.add_slider("F:",eb_params.f,0.1,20)
        
    frm.add_heading("Color grading params")
    slider_max_lum = frm.add_slider("Maximun luminance:",general_params.peak_luminance,400,general_params.peak_luminance_display)
    slider_a = frm.add_slider("Contrast(a):",tmo_params.a,0.0,10.0)
    slider_d = frm.add_slider("Shoulder(d):",tmo_params.d,0.0,10.0)
    slider_midIn = frm.add_slider("Mid In :",tmo_params.midIn,0.0,max_value)
    slider_midOut =  frm.add_slider("Mid Out (*) :",tmo_params.midOut,0.0,1)
    
    frm.add_heading("Video Player")
    vidstate = object()
    [vidstate.is_playing, vidstate.allow_seeking, vidstate.show_next_frame] = [true, true, true]
    button_stop=frm.add_button("Stop")
    button_stop.icon = imread("Media/control_stop_blue.png")
    button_play=frm.add_button("Play")
    button_play.icon = imread("Media/control_play_blue.png")
    button_fullrewind=frm.add_button("Full rewind")
    button_fullrewind.icon = imread("Media/control_start_blue.png")
    position = frm.add_slider("Position",0,0,floor(stream.duration_sec))
    params_display = frm.add_display()
    
    %Events
    slider_brightness_th1.onchange.add(()-> (eb_params.th1 = slider_brightness_th1.value););                        
    
    slider_max_lum.onchange.add(()-> (  general_params.peak_luminance = slider_max_lum.value;
                                        general_params.peak_luminance_r = general_params.peak_luminance/general_params.peak_luminance_display;
                                        general_params.boost_luminance_r = 1-general_params.peak_luminance_r;
                                        tmo_params.peak_luminance_ratio=general_params.peak_luminance_r;));                        
    
    slider_brightness_th2.onchange.add(()-> (eb_params.th2 = slider_brightness_th2.value););                        
    
    slider_brightness_f.onchange.add(()-> (eb_params.f = slider_brightness_f.value););                        
    
    
    cb_moving_line.onchange.add(()-> (cb_no_line.value=false;)); 
    
    cb_side_by_side.onchange.add(()-> (cb_no_line.value=false;
                                       cb_moving_line.value = false;));
    
    cb_no_line.onchange.add(()-> (cb_moving_line.value = false;)); 
    
    slider_a.onchange.add(()-> (tmo_params.a = slider_a.value;
                                updateBC(tmo_params)));      
                                
    slider_d.onchange.add(()-> (tmo_params.d = slider_d.value;
                                updateBC(tmo_params)));    
                                  
    slider_denoising_epsf.onchange.add(()-> (gf_params.epsf = slider_denoising_epsf.value;
                                             gf_params.eps = (gf_params.epsf)^2));      
  
    slider_pocs_steps.onchange.add(()-> (pocs_params.steps = floor(slider_pocs_steps.value)));                                

    button_stop.onclick.add(() -> vidstate.is_playing = false)
    
    button_play.onclick.add(() -> vidstate.is_playing = true)
    
    button_fullrewind.onclick.add(() -> (vidseek(stream, 0); vidstate.show_next_frame = true))    
    
    position.onchange.add(() -> vidstate.allow_seeking ? vidseek(stream, position.value) : [])
  
    %Using mid-level mapping to adjust brightness pre-tonemappingkeeps contrast and saturation consistent 
    slider_midIn.onchange.add(()-> (tmo_params.midIn = slider_midIn.value;
                                updateBC(tmo_params)));          

    slider_midOut.onchange.add(()-> (tmo_params.midOut = slider_midOut.value;
                                updateBC(tmo_params)));                        
                                
    %Denoising
    cb_denoise.onchange.add(()-> (denoising=cb_denoise.value;))
    val_in=float(0.0..max_value/(2^target_bits_per_color-1)..max_value)
    cmploc = s_width/2;
    xloc = mod(cmploc,2*size(frame_show,1))
    
%    vidseek(stream,5)
    repeat
        %tic()
        if(cb_moving_line.value)
            cmploc += floor(s_width/100)
            xloc = mod(cmploc,2*size(frame_show,1))
            if xloc >= size(frame_show,1)
                xloc = 2*size(frame_show,1)-xloc-1
            endif
        endif
        % Reads until there is no frame left. 
        if vidstate.is_playing == true
            if !vidreadframe(stream)
                if looping
                    % Jump back to the first frame
                    vidseek(stream, 0)
                else
                    break % Quit!
                endif
            endif
        endif
        
        %Read frame 
        frame = float(stream.rgb_data);
        
        %Denoising using fast joint bilateral filter (guided filter) 
        if(cb_denoise.value)
            frame_denoised[:,:,0] = fastguidedfilter(frame[:,:,0], frame[:,:,0], gf_params.r, gf_params.eps);
            frame_denoised[:,:,1] = fastguidedfilter(frame[:,:,1], frame[:,:,1], gf_params.r, gf_params.eps);
            frame_denoised[:,:,2] = fastguidedfilter(frame[:,:,2], frame[:,:,2], gf_params.r, gf_params.eps);
            %Clamp values
            frame_denoised=clamp(frame_denoised,255.0)
        else
            frame_denoised=frame
        endif    
        
        %Linearize frame (normalized)
        frame_denoised = linearize(frame_denoised) %Max value
        
%        %Denoising video artifacts due to the compression using NLMeans
%        frame_noisy = make_raw_cube(frame_original)
%        denoise_nlmeans(frame_noisy,frame_denoised, search_wnd, half_block_size, correlated_noise)
%        unmake_raw_cube(frame_noisy,frame_processed)
        
        %Get bright mask
        frame_bright_mask = get_bright_mask(frame_denoised,eb_params)                                
                                                                                                
        %Linear expansion SIM2 16 stops
        frame_expanded=linear_expansion(frame_denoised,max_value) %Expand to max value
             
        %Calc LUT for POCS and iTMO
        lut=color_grade(val_in,tmo_params)
        
        %Grading and get L and H frames
        apply_LUT(frame_expanded,frame_graded,frame_l,frame_u,lut,pocs_params.steps)
        %POCS
        frame_dequant = frame_graded
        if(cb_pocs.value)
            for i = 1..5
                parallel_do(size(frame_expanded),frame_v_buff,frame_dequant,pocs_params.r_pocs,pocs_horizontal_run)
                parallel_do(size(frame_expanded),frame_dequant,frame_v_buff,pocs_params.r_pocs,frame_u,frame_l,pocs_vertical_run)
            end
        endif
        
        %Enhance brightess
        if(cb_enhance_brightness.value)
            frame_dequant = apply_bright_mask(frame_dequant,frame_bright_mask,eb_params.f)
        endif
        
        %Show curve
        params_display.plot(val_in,lut*general_params.peak_luminance_display);
        
        %Create show frame
        %Show mask instead original video
        if(cb_no_line.value)
            frame_show=frame_dequant;
        else
            if(cb_side_by_side.value)
                %Must be 540x960 each image
                frame_show=zeros(size(frame_show)); 
                frame_show[s_height/4..s_height/4+s_height/2-1,0..s_width/2-1,:] = imresize(linearize(frame),0.5,"nearest")/sdr_factor;
                frame_show[s_height/4..s_height/4+s_height/2-1,s_width/2..s_width-1,:] = imresize(frame_dequant,0.5,"nearest")
                
            else
                if(cb_show_brightness_mask.value)
                    frame_show[:,0..xloc,0]=frame_bright_mask[:,0..xloc]
                    frame_show[:,0..xloc,1]=frame_bright_mask[:,0..xloc]
                    frame_show[:,0..xloc,2]=frame_bright_mask[:,0..xloc]
                else
                    frame_show[:,0..xloc,:]=linearize(frame[:,0..xloc,:])/sdr_factor
                endif
                
                %Show processed
                frame_show[:,xloc..s_width-1,:]=frame_dequant[:,xloc..s_width-1,:]
                    
                %Black vertical line
                frame_show[:,xloc..xloc+1,:]=0
            endif
        endif            
        %hdr_imshow(frame_dequant*max_value,[0,max_value])
        h = hdr_imshow(frame_show*max_value,[0,max_value])
       
        % Save in PNG
        if(cb_record.value)
            y = h.rasterize()
            png_path = sprintf(strcat(png_out_folder,"out%08d.png"),png_frame_counter); 
            y= uint8_to_float(y[size(y,0)-1..-1..0,:,:]) %Flip and converto to float



%            %Entire acreen 
            frame_pngsave[20..s_height-15-1,0..size(y,1)-15,:] = y[20..s_height-15-1,0..size(y,1)-15,:]
%            frame_pngsave[:,s_width-26..s_width-1,:]=0;
%            
             %Entire acreen 
%            frame_pngsave[50..50+s_height-10,0..size(y,1)-1,:] = y[10..10+s_height-10,0..size(y,1)-1,:]
%            frame_pngsave[:,s_width-26..s_width-1,:]=0;

            %Black borders           
%            frame_pngsave[132..132+s_height-10,0..size(y,1)-1,:] = y[16..16+s_height-10,0..size(y,1)-1,:]
%            frame_pngsave[:,s_width-26..s_width-1,:]=0;

            %Black borders        
%            frame_pngsave[158..954,0..size(y,1)-1,:] = y[158..954,0..size(y,1)-1,:]
%            frame_pngsave[:,s_width-26..s_width-1,:]=0;
            imwrite(png_path, frame_pngsave)
        endif

        %toc()
        %Update position slider
        position.value = stream.pts
        png_frame_counter=png_frame_counter+1
        pause(0)
    until !hold("on")
end

