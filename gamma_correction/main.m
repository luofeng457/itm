addpath('/u/gluzardo/Documents/phd/openexr-matlab-master');
addpath('/u/gluzardo/Documents/phd/itm/subaxis');
addpath('/u/gluzardo/Documents/phd/itm/hdrvdp-2.2.1');


hdr_folder='/u/gluzardo/Documents/phd/itm/hdr_images/open_exr/';
%ldr_folder='/u/gluzardo/Documents/phd/itm/ldr_images/ldr_pfstools/ldr_mai11/';
image_name='GoldenGate';

hdr_image=exrread(strcat(hdr_folder,image_name,'.exr'));
hdr_info=exrinfo(strcat(hdr_folder,image_name,'.exr'));
disp(hdr_info);
disp(hdr_info.attributes);

%ldr_image=imread(strcat(ldr_folder,image_name,'.jpg'));
ldr_image=tonemap(hdr_image);
  %,'AdjustLightness', [0.1 1], ...
  %                 'AdjustSaturation', 4);

%Convert to HDR, gamma correction
[hdr_out,curve]=ldr2hdr_gammacorrection(ldr_image,2.2);

ldr_out=tonemap(hdr_out);%,'AdjustLightness', [0.1 1], ...
                         %'AdjustSaturation', 4);
figure();
subaxis(1,1,1,'M',0.02,'MT',0.05,'MB',0.06);
imshow(ldr_image);
title('LDR Image');

figure()
subaxis(1,1,1,'M',0.02,'MT',0.05,'MB',0.06);
imshow(ldr_out)
title('HDR-OUT Image');

%Draw channels
figure()
subaxis(2,2,4,'M',0.02,'MT',0.05,'MB',0.06);
plot(curve);
axis([0 255 0 100])
title('Transformation curve');
exrwrite(hdr_out,'hdr_out.exr');
disp('HDR image saved');

%Display in false color 
clims = [0 100];
subaxis(2,2,1)
imagesc(hdr_out(:,:,1),clims);
axis equal; axis off;
title('Channel B');
colorbar

subaxis(2,2,2)
imagesc(hdr_out(:,:,2),clims);
title('Channel G');
axis equal; axis off;
colorbar

subaxis(2,2,3)
imagesc(hdr_out(:,:,3),clims);
title('Channel R');
axis equal; axis off;
colorbar

% % HDR-VP2
% %Load reference and test images
% T = double(ldr_image)/2^8; % images must be
% %                                                  % normalized 0-1
% R = double(hdr_out)/max(hdr_out(:));
% %
% %  % Compute pixels per degree for the viewing conditions
% ppd = hdrvdp_pix_per_deg( 21, [size(0,2) size(0,1)], 1 );
% %
% %  % Run hdrvdp
% res1 = hdrvdp( T, R, 'rgb-bt.709', ppd );
% figure()
% clims = [0 max(res1.P_map(:))];
% imagesc(res1.P_map,clims);
% title('HDR-VPD');
% axis equal; axis off;
% colorbar



