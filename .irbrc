# ref: http://d.hatena.ne.jp/shunsuk/20090106/1231247444
#      http://www.ai.cs.kobe-u.ac.jp/~kawamura/2007-06-22-1.html

require 'rubygems'       # require_gemsでも動くように
require 'irb/completion' # tabで補完
require 'what_methods'   # 3.14.what? 4 で 3.14.ceil == 4 => ["ceil"] みたいな結果からメソッド検索
require 'pp'             # p よりも見やすい
require 'wirble'         # シンタックスハイライト

# IRB設定
IRB.conf[:AUTO_INDENT] = true  # オートインデントを有効に
IRB.conf[:SAVE_HISTORY] = 1000 # 履歴を1000残す

# alias
alias q exit

# Wirbleの設定
Wirble.init
Wirble.colorize

# オブジェクトが持っているlocalのmethodのみを表示する(obj.local_methods)
class Object
  def local_methods
    (methods - Object.instance_methods).sort
  end
end

# Rails(script/console)の場合SQLをSTDOUTにlogる

if ENV.include?('RAILS_ENV') && !Object.const_defined?('RAILS_DEFAULT_LOGGER')
  require 'logger'
  RAILS_DEFAULT_LOGGER = Logger.new(STDOUT)
end
