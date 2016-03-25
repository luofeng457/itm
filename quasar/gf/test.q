import "fastguidedfilter.q"

I = float(imread("cat.bmp"))/255 ; % this image is too small to fully unleash the power of Fast GF
I = I[99..109,19..29,:];
p = I;
r = 4;
eps = 0.2^2; % try eps=0.1^2, 0.2^2, 0.4^2
s = 4; % sampling ratio

q_sub = fastguidedfilter(I[:,:,0], p, r, eps, s);
%
%
%imshow(q_sub, [0, 1]);





