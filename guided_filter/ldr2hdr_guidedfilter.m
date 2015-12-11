% 
%    Function to get HDR 
%
% Author: Gonzalo Luzardo
% Email : gluzardo@telin.ugent.be
%
%
% Usage:

 

function [hdr_image] = ldr2hdr_guidedfilter(ldr_image,max_hdr_value,gamma_correction,nhoodSize,smoothValue)
    %Prepare for joint filter
    hdr_image = max_hdr_value*(im2single(ldr_image)).^gamma_correction; %Perfoma gamma correction
    
    
    
end



