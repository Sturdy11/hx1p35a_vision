// Integer specification independent of the generated RTL case table.
function integer curve69;
 input integer x;
 integer lo,hi,a,b;
 begin
  if(x<=8)begin lo=0;hi=8;a=0;b=12;end
  else if(x<=16)begin lo=8;hi=16;a=12;b=24;end
  else if(x<=32)begin lo=16;hi=32;a=24;b=48;end
  else if(x<=64)begin lo=32;hi=64;a=48;b=92;end
  else if(x<=96)begin lo=64;hi=96;a=92;b=128;end
  else if(x<=128)begin lo=96;hi=128;a=128;b=160;end
  else if(x<=160)begin lo=128;hi=160;a=160;b=189;end
  else if(x<=192)begin lo=160;hi=192;a=189;b=214;end
  else if(x<=224)begin lo=192;hi=224;a=214;b=236;end
  else begin lo=224;hi=255;a=236;b=255;end
  curve69=a+((x-lo)*(b-a)+(hi-lo)/2)/(hi-lo);
 end
endfunction
function integer sat69;
 input integer c,y;
 integer d,v;
 begin
  d=c-y;
  if(d>=0)v=c+d/4;else v=c-((-d+3)/4);
  if(v<0)sat69=0;else if(v>255)sat69=255;else sat69=v;
 end
endfunction
function [23:0] expected69;
 input [23:0] p;
 integer r,g,b,y;
 begin
  r=curve69(p[23:16]);g=curve69(p[15:8]);b=curve69(p[7:0]);
  y=(r+2*g+b)/4;
  expected69=(sat69(r,y)<<16)|(sat69(g,y)<<8)|sat69(b,y);
 end
endfunction
