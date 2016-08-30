% Conversion script EXR to Motion JPEG 2000
% Author: Hiep Luong
clear all

dirname = '/Volumes/EXR/bistro_01/';
vidname = 'bistro_01.avi';
exr_files = dir(strcat(dirname,'*.exr'));

nr = length(exr_files);

% Video parameters
vidObj = VideoWriter(strcat(dirname,vidname),'Uncompressed AVI');
vidObj.FrameRate = 60;
%vidObj.LosslessCompression = true;
%vidObj.MJ2BitDepth = 16;

open(vidObj);

% compute minimum and maximum over the whole video sequence
mi = 2^16;
ma = 0;
for i = 1:nr
    disp(strcat(strcat('Phase 1: reading file ',exr_files(i).name),'...'));
    im = exrread(strcat(dirname,exr_files(i).name));
    
    mi = min(mi,min(im(:)));
    ma = max(ma,max(im(:)));
end

mami = ma - mi;

for i = 1:nr
    disp(strcat(strcat('Phase 2: writing file ',exr_files(i).name),'...'));
    im = exrread(strcat(dirname,exr_files(i).name));
    
    im2 = uint16(2^16.*(im - mi)./mami);
    im2a = uint8(floor(im2./(2^8)));
    im2b = uint8(floor(im2 - uint16(im2a.*2^8)));
    %writeVideo(vidObj,im2);
    writeVideo(vidObj,im2a);
    writeVideo(vidObj,im2b);
end

close(vidObj);