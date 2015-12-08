% 
%    Function to get HDR image using simple Gamma Correction Technique
%
% Author: Gonzalo Luzardo
% Email : gluzardo@telin.ugent.be
%
%
% Usage:
% hdr_image = ldr2hdr_gammacorrection(ldr_image,gamma_value)
% Outputs:
%         hdr_image = High Dynamic Range Image - single precision floating
%         point - MatLab single 32 bits
%         curve = transformation curve (single datatype)
% Inputs:
%         ldr_image = input low dynamic range image file (uint8 data type)
%         gamma_value= gamma correction factor, if not specified gamma = 1
% 

function [hdr_image] = ldr2hdr_sat_bf(ldr_image,sat,w,sigma)
    
    %Saturate 
    hsv = rgb2hsv(ldr_image);
    hsv(:, :, 2) = hsv(:, :, 2) * (1+sat);
    
    hsv(hsv > 1) = 1;  % Limit values
    ldr_image = hsv2rgb(hsv);

    hdr_image = im2double(ldr_image);
    
    hdr_image = bfilter(hdr_image,w,sigma);
    
    
end



