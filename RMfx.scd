//////////////////////////////////// FX START ////////////////////////////////////
(
// chain1 = PV_MagFreeze( chain1, freeze );
// chain1 = PV_BinShift(chain1, 1, chain2);
// chain1 = PV_XFade(chain1, popFreq, 2 );
// var popFreq = EnvGen.ar(Env([3261, 410, 1000], [0.005, 0.01], curve: \exp));

SynthDef(\delayll, {arg ibs,  gate= 1, freqHP= 20, freqLP= 20000, filtRes=0.5, delme = 0.003, delRes = 0.6, delRez = 0.22,
	delFlt = 10000, delTim = 2 ,delFed = 0.5, lfoFrq = 1, lfoAmt = 1, dryWet = 0.5, lagKarme = 0.12;
	var source, limiting, rhpf, rlpf, delayHotLine, delayFiltLine,	delayLFOLine, delayDryWet;
	source = In.ar(ibs);
	source = LeakDC.ar(source);
	rhpf = BHiPass.ar(source, Lag3.kr(freqHP, 0.07), filtRes);
	rlpf = BLowPass.ar(rhpf, Lag3.kr(freqLP, 0.07), filtRes);
	rlpf = Streson.ar(rlpf, delme.reciprocal, delRes);
	rlpf = LeakDC.ar(rlpf);
	delayLFOLine = SinOsc.ar(lfoFrq, mul: lfoAmt, add: delFlt);
	delayFiltLine = IIRFilter.ar(rlpf, Lag2.ar(Fold.ar(delayLFOLine,10,20000),lagKarme),delRez);
	delayHotLine = CombC.ar(delayFiltLine, Lag2.kr(delTim,1.9), Lag2.kr(delTim,1.9),delFed);
	delayDryWet = XFade2.ar(rlpf,delayHotLine,dryWet);
	DetectSilence.ar(delayDryWet, time: 4, doneAction:2);
	//	Out.ar(~recBus10, delayDryWet);
	ReplaceOut.ar(ibs, delayDryWet);
}).add;

///////////////////////////////////////////////////////////////////////////

SynthDef(\freeze,  { arg freeze = 800, ibs, freq=440, bufSize = 1024;
	var chain1, chain2, frozen, inp,temp;
	var	popFreq = EnvGen.ar(Env([3261, 410, 1000], [0.005, 0.01], curve: \exp));
	inp  = In.ar(ibs).asArray;
	temp =  Pulse.ar(rrand(500,800), rrand(0.1,1),rrand(0.2,1));
	chain1 = FFT( LocalBuf( 8192 ! 2 ), inp );
	chain2 = FFT( LocalBuf( 8192 ! 2 ), temp);
	chain1 = PV_CopyPhase( chain1, chain2 );


	frozen = IFFT( chain1 ).asArray;
	frozen = Pan2.ar(frozen,  FSinOsc.kr(2), 1,1.5);
	frozen = frozen * (15).dbamp;
	ReplaceOut.ar( ibs, frozen);
}).add;

///////////////////////////////////////////////////////////////////////////



SynthDef(\ringMod, {arg ibs, carrFreq = 440, modFreq = 2, amp = 0.06, which = 0;
	var carrier, modulator, input, chain1, chain2, output;
	input = In.ar(ibs);
	carrier = Select.ar(which,
		[
			SinOsc.ar(Lag.kr(carrFreq)),
			Blip.ar(Lag.kr(carrFreq), 5),
			Saw.ar(Lag.kr(carrFreq))
	]);
	modulator = SinOsc.ar(Lag.kr(modFreq));
	output = (10).dbamp*( carrier * input );
	// /Out.ar( ~recBus11, output);
	ReplaceOut.ar( ibs, output);
}).add;
///////////////////////////////////////////////////////////////////////////

SynthDef(\nReverb,{arg ibs, maxDelay=0.181, preDelay=0.08, decay=2, numRefl=8, random=0.1;

	var numChan=2;
	var sig, new, dlys;
	#numChan, maxDelay, preDelay, decay, numRefl, random = #[8, 0.219, 0.0008, 12, 24, 0.5];
	sig = In.ar(ibs);
	new = sig;
	dlys = Array.fill(numRefl, {
		new = AllpassN.ar(new, maxDelay,Array.fill(numChan, { random.rand }) + preDelay, decay);
	});
	Mix.ar(dlys * Array.series(numRefl, 1, (numRefl+1).reciprocal.neg));
	ReplaceOut.ar(ibs, dlys);
}).add;




////////////////////////////////////////////////////////////////////////////////

SynthDef(\dubecho,{ arg ibs, length = 0.1, fb = 1, sep = 0.00012, amp = 5;
	var input = In.ar(ibs);
	var magic;var real = 0.2;
	var imag = 0.8;
	var magicL;
	var fft = 0.5;
	var output = input + Fb({
		arg feedback;
		var left,right;
		magic = LeakDC.ar(feedback*fb + input);
		magic = HPF.ar(magic, 400);
		magic = LPF.ar(magic, 5000);
		magic = magic.tanh;
		#left, right = magic;
		magic = [DelayC.ar(left, 1, LFNoise2.ar(12).range(0,sep)), DelayC.ar(right, 1, LFNoise2.ar(12).range(sep,0))];
	},length);
	magic = magic * amp;
	ReplaceOut.ar(ibs,magic);
}).add;

////////////////////////////////////////////////////////////////////////////


SynthDef(\audioPitchShiftDelay, { arg ibs,obs = 0, ratio = 1, delayTime = 0.05;
	var in, retune1, retune2, delayMod, trig, samplePeriod, transNumber;
	var window, start, end, rate;
	in = In.ar(ibs);
	rate = (1 - ratio ) * SampleRate.ir.reciprocal;
	start = 0.0;
	end = delayTime;
	delayMod = Phasor.ar( 0, rate, start, end);
	window = SinOsc.ar(ratio*delayTime.reciprocal,3pi/2, 0.5, 0.5);
	retune1 = DelayC.ar( in, 0.3, delayMod ) * window;
	retune2 = DelayC.ar( retune1, 0.5, (ratio/delayTime).reciprocal*0.5 );
	retune2 =retune1+retune2;
	//Out.ar(~recBus13, [retune1+retune2, retune1+retune2]);
	ReplaceOut.ar(ibs,retune2);

}).add;
)