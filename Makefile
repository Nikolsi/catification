.PHONY: build app run dev test sprites banner demos clean

build:
	swift build

app:
	./scripts/build-app.sh

run: app
	-pkill -x Catification
	open build/Catification.app

dev: build
	-pkill -x Catification
	.build/debug/Catification

test:
	swift test

demos:
	./scripts/record-demos.sh

banner: build
	.build/debug/Catification --render-banner docs/media/banner.gif
	.build/debug/Catification --render-social docs/media/social-preview.png

sprites: build
	mkdir -p .preview
	.build/debug/Catification --dump-sprites .preview/sprites.png
	open .preview/sprites.png

clean:
	rm -rf .build build .preview
