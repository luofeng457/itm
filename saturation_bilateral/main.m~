%addpath('/u/gluzardo/Documents/phd/openexr-matlab-master');
%addpath('/u/gluzardo/Documents/phd/subaxis');
addpath('/Users/gluzardo/Documents/phd/openexr-matlab-master');
addpath('/Users/gluzardo/Documents/phd/itm/subaxis');



ldr_folder='/Users/gluzardo/Documents/phd/itm/ldr_images/cr/';
image_name='sw';


ldr_image=imread(strcat(ldr_folder,image_name,'.jpg'));

%Convert to HDR, gamma correction
hdr_sat_bf=ldr2hdr_sat_bf(ldr_image,0.7,5,[3 0.1]);

figure();
subaxis(1,1,1,'M',0.02,'MT',0.05,'MB',0.06);
imshow(ldr_image);
title('LDR Image');

hdr_out = hdr_sat_bf.^2.2; % Gamma correction
hdr_out = hdr_out*100;
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


