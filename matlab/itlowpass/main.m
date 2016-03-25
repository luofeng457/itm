%POCS
close all
clear all;

im = imread('/u/gluzardo/Documents/phd/itm/ldr_images/cr/toy-story-3-hd.jpg');
im = im2single(im);

gamma_correction = 2.2;

image = floor((im.^(gamma_correction))*255)/255; % inverse gamma
figure;
imshow(uint8(image*255),[0,255]);

imwrite(uint8(255*(image.^(1/gamma_correction))),'image_in.png')

%tmo = tonemap(image*255, 'AdjustLightness', [0.5 1], 'AdjustSaturation', 1.5)/255;
%imshow(tmo,[0,255]);

im_lower = (max(im - 0.5/255,0)).^(gamma_correction);
im_upper = (min(im + 0.5/255,1)).^(gamma_correction);

kernel = [0 1 0; 1 1 1; 0 1 0]./5;

iterations = 200;

for iter = 1:iterations
    image = imfilter(image,kernel,'same','symmetric');

    image = min(image,im_upper);
    image = max(image,im_lower);
end

figure;
imshow(uint8(image*255),[0,255]);

%exrwrite(image,'hdr.exr');
% figure;
% tm = tonemap(image*255, 'AdjustLightness', [0.5 1], 'AdjustSaturation', 1.5);
% imshow(tm,[0,255]);


imwrite(uint8(255*(image.^(1/gamma_correction))),'image_out.png')