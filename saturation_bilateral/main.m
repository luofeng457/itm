addpath('/u/gluzardo/Documents/phd/openexr-matlab-master');
addpath('/u/gluzardo/Documents/phd/itm/subaxis');
addpath('/u/gluzardo/Documents/phd/itm/hdrvdp-2.2.1');

% addpath('/Users/gluzardo/Documents/phd/openexr-matlab-master');
% addpath('/Users/gluzardo/Documents/phd/itm/subaxis');
%ldr_folder='/Users/gluzardo/Documents/phd/itm/ldr_images/cr/';

ldr_folder = '/u/gluzardo/Documents/phd/itm/ldr_images/cr/';
image_name='han_solo_star_wars-2015';


ldr_image=imread(strcat(ldr_folder,image_name,'.jpg'));

%Convert to HDR, gamma correction
hdr_out=ldr2hdr_sat_bf(ldr_image,0.5,5,[1 0.05]); %sat,windows size,sigmad, sigmar

figure();
subaxis(1,1,1,'M',0.02,'MT',0.05,'MB',0.06);
imshow(ldr_image);
title('LDR Image');

exrwrite(hdr_out,'hdr_out.exr');

% %Draw channels
% figure()
% subaxis(2,2,4,'M',0.02,'MT',0.05,'MB',0.06);
% plot(curve);
% axis([0 255 0 100])
% title('Transformation curve');
% exrwrite(hdr_out,'hdr_out.exr');
% disp('HDR image saved');
% 
% %Display in false 
% clims = [0 100];
% subaxis(2,2,1)
% imagesc(hdr_out(:,:,1),clims);
% axis equal; axis off;
% title('Channel B');
% colorbar
% 
% subaxis(2,2,2)
% imagesc(hdr_out(:,:,2),clims);
% title('Channel G');
% axis equal; axis off;
% colorbar
% 
% subaxis(2,2,3)
% imagesc(hdr_out(:,:,3),clims);
% title('Channel R');
% axis equal; axis off;
% colorbar
% 


