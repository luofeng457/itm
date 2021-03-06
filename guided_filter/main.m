%Constants
run('/u/gluzardo/Documents/phd/itm/utils/constants.m');

addpath('/u/gluzardo/Documents/phd/itm/utils/');
addpath('/u/gluzardo/Documents/phd/openexr-matlab-master');
addpath('/u/gluzardo/Documents/phd/itm/subaxis');
addpath('/u/gluzardo/Documents/phd/itm/hdrvdp-2.2.1');

% addpath('/Users/gluzardo/Documents/phd/openexr-matlab-master');
% addpath('/Users/gluzardo/Documents/phd/itm/subaxis');
%ldr_folder='/Users/gluzardo/Documents/phd/itm/ldr_images/cr/';

%ldr_folder = '/u/gluzardo/Documents/phd/itm/ldr_images/cr/';
%image_name='Lanai-at-sunset.png';
%[ldr_image,map]=imread(strcat(ldr_folder,image_name),'png');

ldr_image = imread('/u/gluzardo/Documents/phd/itm/ldr_images/cr/sunsetHD-2.png','png');
%hdr_image = exrread('goldengate.exr');
%ldr_image = tonemap(hdr_image);

figure();
subaxis(1,1,1,'M',0.02,'MT',0.05,'MB',0.06);
imshow(ldr_image);
title('LDR Image');

%Convert to HDR
nhoodSize = 10;
smoothValue  = 10;%0.001*diff(getrangefromclass(ldr_image)).^2;
gamma_correction = 2.2;
hdr_out=ldr2hdr_guidedfilter(ldr_image,max_hdr,gamma_correction,nhoodSize,smoothValue); %Neighborhoodsize, DegreeOfSmoothing

exrwrite(hdr_out,'hdr_out_gf.exr');
 

