defmodule Plausible.Auth.Password do
  def hash(password) do
    Bcrypt.hash_pwd_salt(password)
  end

  def match?(password, hash) do
    Bcrypt.verify_pass(password, hash)
  end

  def dummy_calculation do
    Bcrypt.no_user_verify()
  end
end
