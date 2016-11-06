package tink.web;

import tink.CoreApi;

typedef Session<User> = {
  function getUser():Promise<Option<User>>;  
}