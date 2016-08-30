import "Sim2HDR.dll"
import "Quasar.Video.dll"
import "inttypes.q"
import "Quasar.UI.dll"
import "Quasar.Runtime.dll"
import "imboundary.q"
import "imfilter.q"
import "nlmeans_denoising_video.q"


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
        x : cube' clamped, r : int, high:cube' unchecked, low:cube'unchecked, maxx:int, pos : ivec3)
        sum = 0.0
        for m=0..2*r
            sum += x[pos + [m-r,0,0]]
        end
        if pos[1] >= maxx-2
            y[pos] = (pos[2] == 0)
        else
            y[pos] = min(max(sum/(2*r+1),low[pos]),high[pos])
        endif
end

function y = PQ_EOTF(x)
    %constants
    m1=2610/4096*1/4
    m2=2523/4096*128
    c1=3424/4096
    c2=2413/4096*32
    c3=2392/4096*32

    y = ((x.^(1./m2)-c1)./(c2-c3*x.^(1/m2))).^(1/m1)  
end

function y = gamma_EOTF(x,a)
    y = x.^a
end

% EOTF functions
% writes actual value in y_o, lower bound of quantization limit in low, higher bound in high
function [] = EOTF_LUT(y:cube'unchecked,y_o:cube'unchecked,low:cube'unchecked,high:cube'unchecked,lut:vec'unchecked)
    entries = max(size(lut))
    %y_o = uninit(size(y,0),size(y,1),size(y,2))
    %low = uninit(size(y,0),size(y,1),size(y,2))
    %high = uninit(size(y,0),size(y,1),size(y,2))
    function [] = __kernel__ EOTF_LUT_kern(y_o:cube'unchecked,low:cube'unchecked,high:cube'unchecked,y : cube'unchecked,lut: vec' clamped,resol:int,pos:ivec3)
        index = floor(y[pos[0],pos[1],pos[2]]*(resol-1))
        
        y_o[pos[0],pos[1],pos[2]] = lut[index]
        %low[pos[0],pos[1],pos[2]] = lut[max(index-1,0)]
        %high[pos[0],pos[1],pos[2]] = lut[min(index+1,(resol-1))]
        low[pos[0],pos[1],pos[2]] = lut[index]-(lut[index]-lut[index-1])/2
        high[pos[0],pos[1],pos[2]] = lut[index]+(lut[index+1]-lut[index-1])/2
    end
    parallel_do(size(y),y_o,low,high,y,lut,entries,EOTF_LUT_kern)
end


function [] = unmake_raw_cube(y : cube,x : cube,xloc:int)
    y[:,0..xloc,0..2] = x[:,0..xloc,[2,1,0]]
end

function [] = main()
    %vidstream= vidopen("/ipids/hd2r/10-bit video/Beauty_3840x2160_120fps_420_10bit_YUV.yuv")
    %vidstream= vidopen("/scratch/jaelterm/quasar_video/iminds_demo.mp4")
    %vidstream= vidopen("iminds_demo.mp4")
    vidstream= vidopen("got2.mkv")
    vidseek(vidstream,132)
    vidstream.bits_per_color = 8
    
    %vidstream= vidopen("F:\10-bit-YUV-video\ShakeNDry_3840x2160_120fps_420_10bit_YUV.avi")  
    
    eotf_bits_per_color_input = 8
    target_bits_per_color = 16
    init_gamma=2.4
    
    %lut = PQ_EOTF(0..1/(2^vidstream.bits_per_color-1)..1)
    lut = gamma_EOTF(0..1/(2^eotf_bits_per_color_input-1)..1,init_gamma)
    
    %NLMS settings
    search_wnd = 2
    half_block_size = 1
    correlated_noise = 0
    
    %GUI settings
    frm = form("Video player")
    vidstate = object()
    [vidstate.is_playing, vidstate.allow_seeking, vidstate.show_next_frame] = [true, true, true]
    frm.center()
    frm.show()
    button_stop=frm.add_button("Stop")
    button_stop.icon = imread("Media/control_stop_blue.png")
    button_play=frm.add_button("Play")
    button_play.icon = imread("Media/control_play_blue.png")
    button_fullrewind=frm.add_button("Full rewind")
    button_fullrewind.icon = imread("Media/control_start_blue.png")
    position = frm.add_slider("Position",0,0,vidstream.duration_sec)
    button_stop.onclick.add(() -> vidstate.is_playing = false)
    button_play.onclick.add(() -> vidstate.is_playing = true)
    button_fullrewind.onclick.add(() -> (vidseek(vidstream, 0); vidstate.show_next_frame = true))    
    position.onchange.add(() -> vidstate.allow_seeking ? vidseek(vidstream, position.value) : [])
    slider_gamma = frm.add_slider("Gamma", init_gamma, 0, 8)
    slider_gamma.onchange.add(() -> vidstate.show_next_frame = true)   
    slider_gamma.onchange.add(() -> lut[:] = gamma_EOTF(0..1/(2^eotf_bits_per_color_input-1)..1,slider_gamma.value)) %the colon needs to be here to invoke call by reference in the scope!
    slider_noise = frm.add_slider("Noise", 3, 0, 50)
    slider_noise.onchange.add(() -> vidstate.show_next_frame = true)   
    video_display = frm.add_display()
    
        
    frame_show_noisy = cube(vidstream.frame_height,vidstream.frame_width,4)
    frame_show_denoised = cube(vidstream.frame_height,vidstream.frame_width,4)
    frame_show = cube(vidstream.frame_height,vidstream.frame_width,3)
    frame_l = cube(vidstream.frame_height,vidstream.frame_width,3)
    frame_u = cube(vidstream.frame_height,vidstream.frame_width,3)
    frame_show_v_buff = cube(vidstream.frame_height,vidstream.frame_width,3)
    cmploc = 600
    r = 6 
    
   
    
    sync_framerate(vidstream.avg_frame_rate)
    repeat
        if vidstate.is_playing==true || vidstate.show_next_frame 
            cmploc += floor(vidstream.frame_width/100)
            xloc = mod(cmploc,2*size(frame_show,1))
            if xloc >= size(frame_show,1)
                xloc = 2*size(frame_show,1)-xloc-1
            endif
            tic()
            
            if vidstate.is_playing == true
                success = vidreadframe(vidstream)
            endif

            frame_show = float(vidstream.rgb_data)
            frame_show = frame_show + floor(randn(size(vidstream.rgb_data))*slider_noise.value/255*2^(vidstream.bits_per_color))
            frame_show = max(frame_show,0)
            frame_show = min(frame_show,(2^(vidstream.bits_per_color)-1))
            frame_show_noisy = make_raw_cube(frame_show)
            
            if slider_noise.value~=0
                denoise_nlmeans(frame_show_noisy, frame_show_denoised, slider_noise.value, search_wnd, half_block_size, correlated_noise)
                unmake_raw_cube(frame_show,frame_show_denoised,xloc)
            endif
            
            EOTF_LUT(frame_show/(2^(vidstream.bits_per_color)-1),frame_show,frame_l,frame_u,lut) 
                                  
            for i = 1..2
                parallel_do([size(frame_show,0),min(xloc+r,size(frame_show,1)),size(frame_show,2)],frame_show_v_buff,frame_show,r,pocs_horizontal_run)
                parallel_do([size(frame_show,0),min(xloc,size(frame_show,1)),size(frame_show,2)],frame_show,frame_show_v_buff,r,frame_u,frame_l,xloc,pocs_vertical_run)
            end
            
            %hdr_imshow(frame_show*(2^target_bits_per_color-1),[0,(2^target_bits_per_color-1)])
            %imshow(frame_show*(2^target_bits_per_color-1),[0,(2^target_bits_per_color-1)])
            imshow(frame_show*(2^target_bits_per_color-1),[0,(2^target_bits_per_color-1)])
            
            toc()
        endif
        pause(0)
    until !hold("on")

end