<?php

$config = [
    'admin' => [
        'core:AdminPassword',
    ],
    'example-userpass' => [
        'exampleauth:UserPass',
        'user@example.com:plausible' => [
            'email' => 'user@example.com',
            'first_name' => 'Jane',
            'last_name' => 'Smith'
        ],
        'user1@example.com:plausible' => [
            'email' => 'user1@example.com',
            'first_name' => 'Lenny',
            'last_name' => 'Carr'
        ],
        'user2@example.com:plausible' => [
            'email' => 'user2@example.com',
            'first_name' => 'Jane',
            'last_name' => 'Doorwell'
        ],
    ],
];
