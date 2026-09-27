/// Music and audio management for CapCut-grade video ads.
library;

enum MusicGenre {
  afrobeats('Afrobeats', 'lib/assets/music/afrobeats/'),
  bongoFlava('Bongo Flava', 'lib/assets/music/bongo/'),
  gengetone('Gengetone', 'lib/assets/music/gengetone/'),
  gospel('Gospel', 'lib/assets/music/gospel/'),
  traditional('Traditional', 'lib/assets/music/traditional/'),
  hipHop('Hip Hop', 'lib/assets/music/hiphop/'),
  pop('Pop', 'lib/assets/music/pop/'),
  electronic('Electronic', 'lib/assets/music/electronic/');

  const MusicGenre(this.displayName, this.assetPath);
  final String displayName;
  final String assetPath;
}

enum SoundEffect {
  whoosh('Whoosh', 'whoosh.mp3'),
  pop('Pop', 'pop.mp3'),
  ding('Ding', 'ding.mp3'),
  swoosh('Swoosh', 'swoosh.mp3'),
  transition('Transition', 'transition.mp3'),
  bassBoost('Bass Boost', 'bass_boost.mp3');

  const SoundEffect(this.displayName, this.fileName);
  final String displayName;
  final String fileName;
}

class VideoAdMusicTrack {
  const VideoAdMusicTrack({
    required this.path,
    this.genre = MusicGenre.afrobeats,
    this.volume = 0.3,
    this.ducking = true,
    this.duckingReduction = 0.1,
    this.startTime = Duration.zero,
    this.endTime,
  });

  final String path;
  final MusicGenre genre;
  final double volume;
  final bool ducking;
  final double duckingReduction;
  final Duration startTime;
  final Duration? endTime;

  String get audioInput {
    final startStr = startTime.inSeconds.toString();
    final endStr = endTime != null ? endTime!.inSeconds.toString() : '9999';
    return "-ss $startStr -to $endStr";
  }

  String get volumeFilter => "volume=$volume";

  String get duckFilter {
    if (!ducking) return '';
    // Duck audio when other audio is present (simplified)
    return ",volume='if(lt(t,1),1,if(gt(t,2),1,$duckingReduction))':eval=frame";
  }
}

class VideoAdSoundEffect {
  const VideoAdSoundEffect({
    required this.effect,
    required this.triggerTime,
    this.volume = 0.5,
  });

  final SoundEffect effect;
  final Duration triggerTime;
  final double volume;

  String get delay => triggerTime.inMilliseconds.toString();
}
