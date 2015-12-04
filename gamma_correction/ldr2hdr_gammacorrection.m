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

function [hdr_image,curve] = ldr2hdr_gammacorrection(ldr_image,gamma_value)
    err = 0;
    if nargin < 2
        gamma_value = 1;
        disp('Default value for gamma = 1');
    elseif nargin ==2 && gamma_value < 0
        gamma_value = 1;
        disp('GammaValue < 0, Default value considered, Gammavalue = 1');
    elseif nargin > 2
        disp('Error : Too many input parameters');
        err = 1;
    end

    if err == 0 
        
        %hdr_image=zeros(size(ldr_image),'single'); %32 bits - single precision floating point
        ldr_image=single(ldr_image);
        max_hdr=single(500);
        max_uint8=single(intmax('uint8'));
        hdr_image = max_hdr*((ldr_image./max_uint8).^ gamma_value);
        
        %Creating transformation curve
        curve = single(1:intmax('uint8'));
        curve = max_hdr*((curve./max_uint8).^ gamma_value);
        disp('Gamma correction performed');
    end
end



