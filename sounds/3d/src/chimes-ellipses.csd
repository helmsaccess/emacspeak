<CsoundSynthesizer>
<C  sOptions>
  -o ../../chimes/ellipses.wav
</CsOptions>
<CsInstruments>
sr		=		44100
ksmps=10
nchnls	=		2

		instr 2
kelev line 30, p3, 10
kampenv 	expseg 	.0001, .01, p4, .04, p3, .0001
asig 	rand 	kampenv
afilt 	reson 	asig, 1000, 5
aout 	balance 	afilt, asig
aleft,aright hrtfmove2 aout, 0,kelev, "hrtf-44100-left.dat","hrtf-44100-right.dat"
		outs 	5*aleft, 5*aright
		endin
</CsInstruments>
<CsScore>

 i2 0 0.1 8000 
i2 0.02 0.08 4000 

i2 0.1 0.08 6000 
i2 0.12 0.06 2000 

i2 0.18 0.06 4000 
i2 0.20 0.04 800 
</CsScore>
</CsoundSynthesizer>
