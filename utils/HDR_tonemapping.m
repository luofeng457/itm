% Partial implementation of the HDR tone mapping from:
%
% G.W. Larson, H. Rushmeier, and C. Piatko. A visibility matching tone reproduction operator
% for high dynamic range scenes. IEEE Transactions on Visualization and Computer Graphics,
% 3:291306, 1997
% available online: http://gaia.lbl.gov/btech/papers/39882.pdf
%
% Implemented in Matlab by Saartje De Neve (MSc. Thesis student UGent/TELIN-IPI-iMinds, 2009)

function im_rgb=HDR_tonemapping(im)
% INPUT irradiance map E: im=log(E)./max(max(max(log(E))))) so that we can work with log-values

srgb2lab = makecform('srgb2lab');
lab2srgb = makecform('lab2srgb');

% HDR image is known up to a constant scale factor
im = im - min(min(min(im)));

normalizationfactor = 1/max(max(max(im)));
im_lab = applycform(im*normalizationfactor, srgb2lab); % convert to L*a*b*

% from histeq: "the values of luminosity can span a range from 0 to 100; scale them to [0 1] range (appropriate for MATLAB intensity images of
% class double) before applying the contrast enhancement technique"
max_luminosity = 100;
L = im_lab(:,:,1)/max_luminosity; % L: image with only a luminance component
N = size(L,1)*size(L,2);
Lvector = reshape(L,[N 1]);

% "replace the luminosity layer with the processed data and then convert the image back to the RGB colorspace"

[fbi,bi] = imhist(L);
T = sum(fbi); % total number of samples

%% (1) naive histogram equalization
% Ldmin=0 and Ldmax=1 because of the division by max_luminosity
% BART: by choosing the normalization higher is Lvector between 0 and 1,
%       so that the x-range of interp1 needs to be adjusted. Pay attention to 
%       the fact that the value returned by interp1 is INF outside the specified 
%       domain
cfd = cumsum(fbi)/T; % cumulative frequency distribution
figure,plot(cfd);
%(2) histogram adjustment with a linear ceiling: fbi wordt aangepast
tolerance=T*0.025;
trimmings=T;
while trimmings>tolerance
   trimmings=0;
   T=sum(fbi);
   if T<tolerance
       return 
   end 
   for i=1:length(bi)
       ceiling=T*((bi(length(bi))-bi(1))/length(bi));
       if fbi(i) > ceiling
           trimmings = trimmings+fbi(i)-ceiling;
           fbi(i)=ceiling;
       end
   end
end
T = sum(fbi);
cfd = cumsum(fbi)/T;

% figure,plot(cfd);
%% (3) histogram adjustment based on human contrast sensitivity

cfd_orig = cumsum(fbi)/T;
tolerance=T*0.025;
trimmings=T;
it=0;
while trimmings>tolerance
   trimmings=0;
   T=sum(fbi);
   if T<tolerance
       break;
   end 
   for i=1:length(bi)
       hs=deltaLt(exp(cfd_orig(i)))/deltaLt(exp(bi(i)));
       ceiling=hs*T*((bi(length(bi))-bi(1))/length(bi))*exp(bi(i))*1/exp(cfd_orig(i));
       if fbi(i) > ceiling
           trimmings = trimmings+fbi(i)-ceiling;
           fbi(i)=ceiling;
       end
   end
end
T = sum(fbi);
cfd = cumsum(fbi)/T;


%figure,plot(cfd);
%%
Lvector = interp1(linspace(0,1,length(cfd)),transpose(cfd),Lvector)*max_luminosity;
im_lab(:,:,1) = reshape(Lvector,[size(L,1) size(L,2)]);
im_lab(:,:,2) = im_lab(:,:,2);
im_lab(:,:,3) = im_lab(:,:,3);

% BART: display the histogram to check - must be more or less flat
%plot(hist(reshape(im_lab(:,:,1),[N 1]),max_luminosity)); pause(0.1);

im_rgb = applycform(im_lab, lab2srgb);
% BART: scale back to 0-255
im_rgb = im_rgb*255;

imagesc(uint8(im_rgb));

