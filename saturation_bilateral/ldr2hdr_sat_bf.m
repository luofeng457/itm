% 
%    Function to get HDR 
%
% Author: Gonzalo Luzardo
% Email : gluzardo@telin.ugent.be
%
%
% Usage:

 

function [hdr_image] = ldr2hdr_sat_bf(ldr_image,sat,w,sigma)
    
    %Saturate 
    hsv = rgb2hsv(ldr_image);
    hsv(:, :, 2) = hsv(:, :, 2) * (1+sat);
    hsv(hsv > 1) = 1;  % Limit values
    
    %Prepare for bilateral filter
    ldr_image = hsv2rgb(hsv);
    hdr_image = im2double(ldr_image);
    %Applying bilateral filter
    hdr_image = bfilter(hdr_image,w,sigma);
    
    %Return gamma correction and scale hdr
    max_hdr=single(100.0);
    hdr_image = hdr_image.^2.2;
    hdr_image = single(hdr_image)*max_hdr;
    
end



