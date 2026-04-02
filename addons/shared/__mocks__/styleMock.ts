/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

// return a proxy so css modules imports give strings like class names
// e.g. import style from './style.css'; style.myClass => 'myClass'

const obj = {};
export default new Proxy(obj, {
  get: (_, prop) => prop,
});
