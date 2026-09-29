# Changelog

## [2.2.0](https://github.com/roschaefer/blame.nvim/compare/v2.1.0...v2.2.0) (2026-09-29)


### Features

* **view:** let users add their own keymaps to the view with on_attach ([#61](https://github.com/roschaefer/blame.nvim/issues/61)) ([8322829](https://github.com/roschaefer/blame.nvim/commit/8322829d5c050a80ba58a31e958015e72df8620d)), closes [#51](https://github.com/roschaefer/blame.nvim/issues/51)


### Bug Fixes

* **view:** keep the cursor in its row of the window when navigating ([#66](https://github.com/roschaefer/blame.nvim/issues/66)) ([48bfcaa](https://github.com/roschaefer/blame.nvim/commit/48bfcaa26a114b2376ef71478236b70101c0bb25))
* **view:** keep the cursor on its line when blaming prior to a commit ([#64](https://github.com/roschaefer/blame.nvim/issues/64)) ([6b4346d](https://github.com/roschaefer/blame.nvim/commit/6b4346d77827d5c111db40fb339994806fbceb3e))

## [2.1.0](https://github.com/roschaefer/blame.nvim/compare/v2.0.0...v2.1.0) (2026-09-28)


### Features

* **view:** mark the lines of the commit under the cursor ([#57](https://github.com/roschaefer/blame.nvim/issues/57)) ([228f4da](https://github.com/roschaefer/blame.nvim/commit/228f4dabe85b0ece491249cd33da13a89c8aa2ee))
* **view:** move from block to block with j and k in the blame window ([#58](https://github.com/roschaefer/blame.nvim/issues/58)) ([20f7ab8](https://github.com/roschaefer/blame.nvim/commit/20f7ab8133dbecc26a70d52a1d609e380787b9d3))
* **view:** show date, author and subject like GitHub's blame view ([#56](https://github.com/roschaefer/blame.nvim/issues/56)) ([158a644](https://github.com/roschaefer/blame.nvim/commit/158a644c0d2b94be631455cbb67278c8fda3bb6b)), closes [#47](https://github.com/roschaefer/blame.nvim/issues/47)
* **view:** show the age of each commit in a coloured stripe ([#59](https://github.com/roschaefer/blame.nvim/issues/59)) ([9e219d8](https://github.com/roschaefer/blame.nvim/commit/9e219d850fdc5ce9433c98e577be313b3022e66f))
* **view:** show the commit message of the cursor line on demand ([#52](https://github.com/roschaefer/blame.nvim/issues/52)) ([4d7162a](https://github.com/roschaefer/blame.nvim/commit/4d7162a52885a9974d4e9a99390f90d840f1c6f7)), closes [#13](https://github.com/roschaefer/blame.nvim/issues/13)


### Bug Fixes

* **view:** let files opened from an explorer replace the view ([#55](https://github.com/roschaefer/blame.nvim/issues/55)) ([cb58db6](https://github.com/roschaefer/blame.nvim/commit/cb58db6107522cd173204a549dec9916ebe4aac6))

## [2.0.0](https://github.com/roschaefer/blame.nvim/compare/v1.2.0...v2.0.0) (2026-09-24)


### ⚠ BREAKING CHANGES

* **view:** replace nui popups with synced splits in a tab page ([#45](https://github.com/roschaefer/blame.nvim/issues/45))

### Features

* **navigation:** move cursor to commit_info.source_line ([#37](https://github.com/roschaefer/blame.nvim/issues/37)) ([9480b82](https://github.com/roschaefer/blame.nvim/commit/9480b82604157131f90c9b2e0d8a0002857690cd))
* **navigation:** restore old cursor position ([#40](https://github.com/roschaefer/blame.nvim/issues/40)) ([a315963](https://github.com/roschaefer/blame.nvim/commit/a315963b7fb68fa593cb7b05b2f105206e0e2a54))
* **scripts:** add script to run Neovim with lazy.nvim and plugin activated ([#42](https://github.com/roschaefer/blame.nvim/issues/42)) ([45ec4e6](https://github.com/roschaefer/blame.nvim/commit/45ec4e6aa86d12695dc1c3fa053cc8260e35e674))
* **scripts:** run own Neovim config with local plugin copy ([#44](https://github.com/roschaefer/blame.nvim/issues/44)) ([f6aa242](https://github.com/roschaefer/blame.nvim/commit/f6aa242d3754bf6f8c896fe11bd91459ccbfc0c4))
* **view:** replace nui popups with synced splits in a tab page ([#45](https://github.com/roschaefer/blame.nvim/issues/45)) ([a5b8884](https://github.com/roschaefer/blame.nvim/commit/a5b888420a7f37b42380bf5e64f2c32ffcca8662))

## [1.2.0](https://github.com/roschaefer/blame.nvim/compare/v1.1.0...v1.2.0) (2026-02-23)


### Features

* **blame_view:** switch between popups with &lt;TAB&gt; ([#36](https://github.com/roschaefer/blame.nvim/issues/36)) ([38ef0cf](https://github.com/roschaefer/blame.nvim/commit/38ef0cff603957f723c12653dab8cc223e617f7e))
* **blame_window:** display commit and filename in the title ([#30](https://github.com/roschaefer/blame.nvim/issues/30)) ([20b750f](https://github.com/roschaefer/blame.nvim/commit/20b750fb18ad476c7b906372bc1ae2819fd260fd))


### Bug Fixes

* **blame_view:** remove remaining line after update ([#34](https://github.com/roschaefer/blame.nvim/issues/34)) ([129a311](https://github.com/roschaefer/blame.nvim/commit/129a3117a98685142f3524af70a7e71cf599e36f))


### Performance Improvements

* **blame_view:** update views with just one system command ([#33](https://github.com/roschaefer/blame.nvim/issues/33)) ([68c2596](https://github.com/roschaefer/blame.nvim/commit/68c259623ddd90b1bf6679323f9c302ca7399b1d))

## [1.1.0](https://github.com/roschaefer/blame.nvim/compare/v1.0.0...v1.1.0) (2026-02-20)


### Features

* **blame_view:** add keymap to close the window ([#29](https://github.com/roschaefer/blame.nvim/issues/29)) ([d0171e4](https://github.com/roschaefer/blame.nvim/commit/d0171e4cffd61ec840d679fa7b19b26427c6c094))
* **navigation:** navigate to the previous revision of a line ([#27](https://github.com/roschaefer/blame.nvim/issues/27)) ([76207ea](https://github.com/roschaefer/blame.nvim/commit/76207ea0824dec492407d4b646b1ac846148071b))
* **ui:** show current commit in file popup title ([#6](https://github.com/roschaefer/blame.nvim/issues/6)) ([98f901e](https://github.com/roschaefer/blame.nvim/commit/98f901e4fd9728f23e29d14606e5e2e01ebedcc8))


### Bug Fixes

* **ui:** avoid resetting the scroll position on navigation ([#9](https://github.com/roschaefer/blame.nvim/issues/9)) ([3e9590d](https://github.com/roschaefer/blame.nvim/commit/3e9590d307ba9a30b6346686af1719123e36bbc0))

## 1.0.0 (2026-02-17)


### Features

* Add README.md ([8243170](https://github.com/roschaefer/blame.nvim/commit/8243170938de0ffc5177795404d7a0ec357757c6))
* Initial commit ([2fa6a1b](https://github.com/roschaefer/blame.nvim/commit/2fa6a1b92d6cca294e3c6cb6a7df01b71846c462))


### Bug Fixes

* panvimdoc github action ([0bf78e2](https://github.com/roschaefer/blame.nvim/commit/0bf78e2feb8eca8feeb21eefd76f9458bb66dbe4))
