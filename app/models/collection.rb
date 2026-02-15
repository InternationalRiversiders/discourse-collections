class Collection < ActiveRecord::Base
  belongs_to :user
  has_many :collection_items, dependent: :destroy
  has_many :topics, through: :collection_items

  validates :title, presence: true, length: { maximum: 100 }

  # 简单的作用域：只显示公开的或者属于当前用户的
  scope :visible_to, ->(user) {
    if user
      where("is_public = true OR user_id = ?", user.id)
    else
      where(is_public: true)
    end
  }
end