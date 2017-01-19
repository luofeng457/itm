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
import "C:\Users\ipi\Documents\gluzardo\eotf_pq\quasar\transfer_functions.q"


function [] = main()
    video_file_hdr = "F:\HDR-SDR+-SDR\HDR 4K nits\BikeSparklersClip.avi"
    stream = vidopen(video_file_hdr) % Opens the specified video file for playing
    s_width=stream.frame_width
    s_height=stream.frame_height
    looping = true

    sync_framerate(stream.avg_frame_rate) 
 
    max_value=2^16;
    looping = true
    
%   vidseek(stream,5)
    repeat
        % Reads until there is no frame left. 
        if (!vidreadframe(stream))
            if looping
                % Jump back to the first frame
                vidseek(stream, 0) 
            else
                break % Quit!  
            endif
        endif
        
        %Read frames
        frame = float(stream.rgb_data)/max_value
        %Color transform
        frame = csdecodeRec2020(frame) %p3 to xyz
        frame = csencodeSRGB(frame) %xyz to rec709
        
        %Linearize using PQ eotf
        frame = PQ_EOTF_PHILIPS(frame)
        
        h = hdr_imshow(frame*4000,[0,6000])
        pause(0)
    until !hold("on")
end

