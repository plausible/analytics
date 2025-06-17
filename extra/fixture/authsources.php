<?php

$config = [
    'admin' => [
        'core:AdminPassword',
    ],
    'example-userpass' => [
        'exampleauth:UserPass',
        'user@plausible.test:plausible' => [
            'email' => 'user@plausible.test',
            'first_name' => 'Jane',
            'last_name' => 'Smith'
        ],
        'user1@plausible.test:plausible' => [
            'email' => 'user1@plausible.test',
            'first_name' => 'Lenny',
            'last_name' => 'Carr'
        ],
        'user2@plausible.test:plausible' => [
            'email' => 'user2@plausible.test',
            'first_name' => 'Jane',
            'last_name' => 'Doorwell'
        ],
    ],
];
