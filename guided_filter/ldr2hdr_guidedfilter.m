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
    A = (im2single(ldr_image).^gamma_correction); %Perfom gamma correction
    hdr = A*max_hdr_value;
    
    reference=ldr_image;
        
    hdr_image = imguidedfilter(hdr,reference, 'NeighborhoodSize',nhoodSize,'DegreeOfSmoothing',smoothValue);
    hdr_image(hdr_image<0)=0;
end



