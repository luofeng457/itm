import "Sim2HDR.dll"
import "Quasar.Video.dll"
import "inttypes.q"
import "Quasar.UI.dll"
import "Quasar.Runtime.dll"
import "imfilter.q"

%x = imread("sunrise_flanker_by_billym12345-d8q0gc5.png");
%x = imread("Taper-Candle-white.jpg");
%vidstream = vidopen("x265-Eldorado_HD_HDR_10bit.mp4")
%vidstream = vidopen("SSFD_Exodus_HDR_High_LUX_UHD_HightlightGrade_HEVC_Main10_45-60VBR_OrigTrax_AAC_Surround_TC_from_TIF.track_291_meta_audio.mp4")
%vidstream = vidopen("Bosphorus_3840x2160_120fps_420_10bit_YUV.yuv")
%gamma = 1.0


%vidstream = vidopen("Life_of_Pi_draft_Ultra-HD_HDR.mp4")
%vidstream = vidopen("Life_of_Pi_draft_Ultra-HD_HDR_small.avi")
%gamma = 4

%vidstream= vidopen("h265_10bit_51Mbit_59fps_Samsung_UHD_Phantom_Flex.ts")
%gamma = 2.2

%vidstream= vidopen("h265_10bit_51Mbit_30fps_Samsung_UHD_Phantom_Flex_small.avi")
%vidseek(vidstream,35)
%gamma = 2.2

% #####################
% Samsung ads

% ****
%vidstream= vidopen("E:\ok_h265_10bit_51Mbit_59fps_Samsung_SUHD_Sensational_Picture_1920.avi")
%gamma = 2.2
%
%vidstream= vidopen("E:\ok_h265_10bit_51Mbit_29fps_Samsung_SUHD_Tech_Story_Europe.avi")
%gamma = 2.2
% ***
%vidstream= vidopen("E:\ok_h265_10bit_51Mbit_59fps_Samsung_SUHD_Journey_of_Color.avi")
%gamma = 2.2

vidstream= vidopen("E:\h265_10bit_51Mbit_30fps_Samsung_UHD_Phantom_Flex.avi")
gamma = 1.5
dequant = 1
vidseek(vidstream,7)

% ####################  YUV 10 bits

%vidstream= vidopen("D:\10-bit-YUV-video\Beauty_3840x2160_120fps_420_10bit_YUV.avi")
%gamma = 4

%vidstream= vidopen("D:\10-bit-YUV-video\Bosphorus_3840x2160_120fps_420_10bit_YUV.avi")
%gamma = 4

%vidstream= vidopen("D:\10-bit-YUV-video\HoneyBee_3840x2160_120fps_420_10bit_YUV.avi")
%gamma = 2.2

%vidstream= vidopen("D:\10-bit-YUV-video\Jockey_3840x2160_120fps_420_10bit_YUV.avi")
%gamma = 2.2

%****
%vidstream= vidopen("D:\10-bit-YUV-video\ReadySetGo_3840x2160_120fps_420_10bit_YUV.avi")
%gamma = 2.2

%vidstream= vidopen("D:\10-bit-YUV-video\ShakeNDry_3840x2160_120fps_420_10bit_YUV.avi")
%gamma = 2.2

%****
%vidstream= vidopen("D:\10-bit-YUV-video\YachtRide_3840x2160_120fps_420_10bit_YUV.avi")
%gamma = 2.2


% ###########  Stuttgart color graded

%****
%vidstream= vidopen("D:\Stuttgart-color-graded\bistro.avi")
%gamma = 3

%****
%vidstream= vidopen("D:\Stuttgart-color-graded\carousel_fireworks.avi")
%gamma = 2.2*2.2

%vidstream= vidopen("D:\Stuttgart-color-graded\fireplace.avi")
%gamma = 3

%*****
%vidstream= vidopen("D:\Stuttgart-color-graded\fishing_longshot.avi")
%gamma = 2.2

%vidstream= vidopen("D:\Stuttgart-color-graded\poker_fullshot.avi")
%gamma = 2.2*2.2

%vidstream= vidopen("D:\Stuttgart-color-graded\poker_travelling_slowmotion.avi")
%gamma = 2.2*2.2

%vidstream= vidopen("D:\Stuttgart-color-graded\showgirl_01.avi")
%gamma = 2.2*2.2

%vidstream= vidopen("D:\Stuttgart-color-graded\showgirl_02.avi")
%gamma = 2.2*2.2



% ##### TRAILERS ###### Faster !!!!!!!!!!

% ##################
%vidstream = vidopen("D:\HEVC-Main10-HDR-Trailers\Life_of_Pi_draft_Ultra-HD_HDR.avi")
%gamma = 4
%
%%vidstream = vidopen("D:\HEVC-Main10-HDR-Trailers\SSFD_Exodus_HDR_High_LUX_UHD_HightlightGrade_HEVC_Main10_45-60VBR_OrigTrax_AAC_Surround_TC_from_TIF.track_291_meta_audio.avi")
%%gamma = 4
%
%%vidstream = vidopen("D:\HEVC-Main10-HDR-Trailers\x265-Eldorado_HD_HDR_10bit.avi")
%%gamma = 4


% #######################
%vidstream = vidopen("got2.mkv")
%gamma = 2.2
%vidseek(vidstream,60*2)

%vidstream= vidopen("showgirl_01.mkv")
%gamma = 2.2

%vidstream= vidopen("boarder.avi")

%vidstream= vidopen("bistro_01.mj2")
%vidstream= vidopen("videoplayback.mp4")
%vidseek(vidstream,35)

%vidstream = vidopen("got1.mkv")
%vidseek(vidstream,60*17+30)
%vidseek(vidstream,60*40+20)

%vidstream = vidopen("budapest.mp4")
%vidseek(vidstream,9*60+16)

%vidstream = vidopen("DC_HIGHCONTRAST.mov")

%frame_test:cube[uint16]'unchecked = cube[uint16](1080,1920,3)
%frmjos = form()
%dspjos = frmjos.add_display()
%frmjef = form()
%dspjef = frmjef.add_display()

mask = ones(21,21)
mask = mask/sum(mask)

sync_framerate(vidstream.avg_frame_rate)
if vidstream.bits_per_color>8
    repeat 
        success = vidreadframe(vidstream) 
        frame:cube[uint16] = vidstream.rgb_data 
        frame_show = (256*256-1)*((uint16_to_float(frame)/(256*256-1)).^gamma)
        frame_l = (256*256-1)*max((((frame_show./(256*256-1)).^(1./gamma) - 0.5/(255)).^gamma),0)
        frame_u = (256*256-1)*min((((frame_show./(256*256-1)).^(1./gamma) + 0.5/(255)).^gamma),1)
        
        if dequant==1
            tic()
            for i=1..2
                frame_show = imfilter(frame_show,mask,[11,11],"circular")
            
                frame_show = max(frame_show,frame_l)
                frame_show = min(frame_show,frame_u)
            end
            toc()
        endif
        hdr_imshow(frame_show,[0,256*256-1])
        
    %    gandalf = dspjef.imshow(frame,[0,256*256-1])
    %    dspjos.imshow(zeros(100,100))
    %    hold("on")
    %    boris = hdr_imshow(frame,[0,256*256-1])
    %    boris.update()
    %    gandalf.connect(boris)
    until !hold("on")
elseif vidstream.bits_per_color==8
    repeat 
        success = vidreadframe(vidstream) 
        framel:cube[uint8] = vidstream.rgb_data
        framelf = uint8_to_float(framel)
        framelf = framelf.^2
        hdr_imshow(framelf,[0,256*256-1])
        
    until !hold("on")
else
    print "bit depth too low"
endif