import "Sim2HDR.dll"
import "Quasar.Video.dll"
import "inttypes.q"
import "Quasar.UI.dll"
import "Quasar.Runtime.dll"
import "imboundary.q"
import "imfilter.q"


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
            y[pos] = (pos[2] == 0)*65535
        else
            y[pos] = min(max(sum/(2*r+1),low[pos]),high[pos])
        endif
end

function [] = main()
    %vidstream= vidopen("F:\h265_10bit_51Mbit_30fps_Samsung_UHD_Phantom_Flex.avi")
    vidstream= vidopen("F:/movie_trailers/dawnoftheplanetoftheapes-tlr2_h1080p.mov")
    gamma = 1.3
    
    vidseek(vidstream,15)
    r = 6

    cmploc = 600


    frame_l = cube(vidstream.frame_height,vidstream.frame_width,3)
    frame_u = cube(vidstream.frame_height,vidstream.frame_width,3)
    frame_show = cube(vidstream.frame_height,vidstream.frame_width,3)
    frame_show_v_buff = cube(vidstream.frame_height,vidstream.frame_width,3)
    
    

    sync_framerate(vidstream.avg_frame_rate)
    ctr=0
    if vidstream.bits_per_color>8
        repeat 
            cmploc += 3
            xloc = mod(cmploc,2*size(frame_show,1))
            if xloc >= size(frame_show,1)
                xloc = 2*size(frame_show,1)-xloc-1
            endif
            tic()
            success = vidreadframe(vidstream)
            function [] = __kernel__ get_bounds(rgb_data:cube[uint16],frame_s_buffer:cube,frame_l_buffer:cube,frame_u_buffer:cube,pos:ivec2)
                for c = 0..2
                    raw_val =rgb_data[pos[0],pos[1],c]/65535
                    frame_s_buffer[pos[0],pos[1],c] = 65535*(raw_val)^gamma
                    frame_l_buffer[pos[0],pos[1],c] = 65535*max((raw_val - 0.5/255)^gamma,0)
                    frame_u_buffer[pos[0],pos[1],c] = 65535*min((raw_val + 0.5/255)^gamma,1)
                end
            end
            parallel_do([vidstream.frame_height,vidstream.frame_width],vidstream.rgb_data,frame_show,frame_l,frame_u,get_bounds)
            
            for i = 1..4
                parallel_do([size(frame_show,0),min(xloc+r,size(frame_show,1)),size(frame_show,2)],frame_show_v_buff,frame_show,r,pocs_horizontal_run)
                parallel_do([size(frame_show,0),min(xloc,size(frame_show,1)),size(frame_show,2)],frame_show,frame_show_v_buff,r,frame_u,frame_l,xloc,pocs_vertical_run)
            end
            hdr_imshow(frame_show,[0,256*256-1])
            toc()
            ctr=ctr+1
            if ctr==260
                vidseek(vidstream,240)
            endif
            if ctr==360
                vidseek(vidstream,109)
            endif
            if ctr>600
                ctr=0
                vidseek(vidstream,15)
            endif
        until !hold("on")
    else
        print "bit depth too low"
    endif

end